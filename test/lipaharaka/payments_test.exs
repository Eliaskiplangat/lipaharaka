defmodule Lipaharaka.PaymentsTest do
  use Lipaharaka.DataCase, async: false

  alias Lipaharaka.{Accounts, Businesses, Invoicing, Payments}

  @invoice_attrs %{
    "buyer_name" => "Zuri Retail Ltd",
    "buyer_phone" => "0798765432",
    "issue_date" => "2026-08-12",
    "due_date" => "2026-08-26",
    "line_items" => [%{"description" => "Office desks", "quantity" => 8, "unit_price" => "6500.00"}]
  }

  setup do
    Lipaharaka.SMS.Test.clear()
    Lipaharaka.Mpesa.Test.clear()
    {:ok, user} = Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})
    {:ok, business} = Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
    {:ok, invoice} = Invoicing.create_invoice(business, @invoice_attrs)
    %{business: business, invoice: invoice}
  end

  describe "request_payment/2" do
    test "returns :invalid_invoice_status for a draft invoice", %{business: business, invoice: invoice} do
      assert {:error, :invalid_invoice_status} = Payments.request_payment(business, invoice.id)
    end

    test "returns :not_found for a nonexistent invoice", %{business: business} do
      assert {:error, :not_found} = Payments.request_payment(business, Ecto.UUID.generate())
    end

    test "initiates an STK Push and creates a pending Payment for a sent invoice", %{
      business: business,
      invoice: invoice
    } do
      {:ok, sent} = Invoicing.send_invoice(business, invoice.id)

      assert {:ok, payment} = Payments.request_payment(business, sent.id)
      assert payment.status == "pending"
      assert payment.phone_number == sent.buyer_phone
      assert Decimal.equal?(payment.amount, sent.total)
      refute is_nil(payment.checkout_request_id)

      mpesa_request = Lipaharaka.Mpesa.Test.last_request()
      assert mpesa_request.account_reference == sent.invoice_number
      assert mpesa_request.checkout_request_id == payment.checkout_request_id
    end
  end

  describe "handle_callback/1" do
    setup %{business: business, invoice: invoice} do
      {:ok, sent} = Invoicing.send_invoice(business, invoice.id)
      {:ok, payment} = Payments.request_payment(business, sent.id)
      %{sent_invoice: sent, payment: payment}
    end

    test "marks the payment success and the invoice paid on ResultCode 0", %{
      payment: payment,
      sent_invoice: sent_invoice,
      business: business
    } do
      callback = Lipaharaka.Mpesa.Test.simulate_callback(payment.checkout_request_id, amount: sent_invoice.total)

      assert {:ok, updated_payment} = Payments.handle_callback(callback)
      assert updated_payment.status == "success"
      refute is_nil(updated_payment.mpesa_receipt_number)

      paid_invoice = Invoicing.get_invoice_for_business(business, sent_invoice.id)
      assert paid_invoice.status == "paid"
    end

    test "marks the payment failed on a non-zero ResultCode, invoice stays sent", %{
      payment: payment,
      sent_invoice: sent_invoice,
      business: business
    } do
      callback =
        Lipaharaka.Mpesa.Test.simulate_callback(payment.checkout_request_id,
          result_code: 1032,
          result_desc: "Request cancelled by user"
        )

      assert {:ok, updated_payment} = Payments.handle_callback(callback)
      assert updated_payment.status == "failed"
      assert updated_payment.result_desc == "Request cancelled by user"

      still_sent_invoice = Invoicing.get_invoice_for_business(business, sent_invoice.id)
      assert still_sent_invoice.status == "sent"
    end

    test "returns :unmatched_callback for an unknown CheckoutRequestID" do
      callback = Lipaharaka.Mpesa.Test.simulate_callback("never-heard-of-this-checkout-id")
      assert {:error, :unmatched_callback} = Payments.handle_callback(callback)
    end

    test "returns :invalid_callback for a malformed payload" do
      assert {:error, :invalid_callback} = Payments.handle_callback(%{"not" => "a real callback"})
    end

    test "is idempotent — a callback arriving after the invoice was already cancelled doesn't crash", %{
      payment: payment,
      sent_invoice: sent_invoice,
      business: business
    } do
      {:ok, _cancelled} = Invoicing.cancel_invoice(business, sent_invoice.id)

      callback = Lipaharaka.Mpesa.Test.simulate_callback(payment.checkout_request_id, amount: sent_invoice.total)

      assert {:ok, updated_payment} = Payments.handle_callback(callback)
      assert updated_payment.status == "success"

      # The payment itself is recorded successful even though the
      # invoice couldn't be transitioned (already cancelled) — this
      # is the documented, expected race, not a bug.
      still_cancelled = Invoicing.get_invoice_for_business(business, sent_invoice.id)
      assert still_cancelled.status == "cancelled"
    end
  end
end
