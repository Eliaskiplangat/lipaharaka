defmodule LipaharakaWeb.MpesaCallbackControllerTest do
  use LipaharakaWeb.ConnCase, async: false

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
    {:ok, sent} = Invoicing.send_invoice(business, invoice.id)
    {:ok, payment} = Payments.request_payment(business, sent.id)

    %{business: business, invoice: sent, payment: payment}
  end

  describe "POST /api/mpesa/callback" do
    test "requires no authentication at all", %{conn: conn, payment: payment} do
      # Deliberately using a bare, unauthenticated conn — this route
      # must be reachable by Safaricom, which has no bearer token.
      callback = Lipaharaka.Mpesa.Test.simulate_callback(payment.checkout_request_id, amount: payment.amount)
      conn = post(conn, ~p"/api/mpesa/callback", callback)

      assert %{"ResultCode" => 0} = json_response(conn, 200)
    end

    test "marks the invoice paid on a successful callback", %{conn: conn, business: business, invoice: invoice, payment: payment} do
      callback = Lipaharaka.Mpesa.Test.simulate_callback(payment.checkout_request_id, amount: payment.amount)
      post(conn, ~p"/api/mpesa/callback", callback)

      updated = Invoicing.get_invoice_for_business(business, invoice.id)
      assert updated.status == "paid"
    end

    test "still acknowledges with 200 for an unmatched checkout id", %{conn: conn} do
      callback = Lipaharaka.Mpesa.Test.simulate_callback("totally-unknown-checkout-id")
      conn = post(conn, ~p"/api/mpesa/callback", callback)

      assert %{"ResultCode" => 0} = json_response(conn, 200)
    end

    test "still acknowledges with 200 for a malformed payload", %{conn: conn} do
      conn = post(conn, ~p"/api/mpesa/callback", %{"garbage" => true})
      assert %{"ResultCode" => 0} = json_response(conn, 200)
    end

    test "invoice stays sent on a failed/cancelled callback", %{conn: conn, business: business, invoice: invoice, payment: payment} do
      callback =
        Lipaharaka.Mpesa.Test.simulate_callback(payment.checkout_request_id,
          result_code: 1032,
          result_desc: "Request cancelled by user"
        )

      post(conn, ~p"/api/mpesa/callback", callback)

      updated = Invoicing.get_invoice_for_business(business, invoice.id)
      assert updated.status == "sent"
    end
  end
end
