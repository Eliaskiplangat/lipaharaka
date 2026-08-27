defmodule Lipaharaka.InvoicingTest do
  use Lipaharaka.DataCase, async: false

  alias Lipaharaka.{Accounts, Businesses, Invoicing}

  setup do
    Lipaharaka.SMS.Test.clear()
    {:ok, user} = Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})
    {:ok, business} = Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
    %{business: business}
  end

  @valid_attrs %{
    "buyer_name" => "Zuri Retail Ltd",
    "buyer_phone" => "0798765432",
    "issue_date" => "2026-08-12",
    "due_date" => "2026-08-26",
    "line_items" => [
      %{"description" => "Office desks", "quantity" => 8, "unit_price" => "6500.00"},
      %{"description" => "Ergonomic chairs", "quantity" => 5, "unit_price" => "2500.00"}
    ]
  }

  describe "create_invoice/2" do
    test "creates an invoice with correctly computed totals", %{business: business} do
      assert {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)

      assert invoice.invoice_number == "INV-0001"
      assert invoice.status == "draft"
      assert Decimal.equal?(invoice.subtotal, Decimal.new("64500.00"))
      assert Decimal.equal?(invoice.tax_amount, Decimal.new("0"))
      assert Decimal.equal?(invoice.total, Decimal.new("64500.00"))
      assert length(invoice.line_items) == 2
    end

    test "applies tax_rate correctly", %{business: business} do
      attrs = Map.put(@valid_attrs, "tax_rate", "16")
      assert {:ok, invoice} = Invoicing.create_invoice(business, attrs)

      assert Decimal.equal?(invoice.subtotal, Decimal.new("64500.00"))
      assert Decimal.equal?(invoice.tax_amount, Decimal.new("10320.00"))
      assert Decimal.equal?(invoice.total, Decimal.new("74820.00"))
    end

    test "invoice numbers increment sequentially per business", %{business: business} do
      {:ok, first} = Invoicing.create_invoice(business, @valid_attrs)
      {:ok, second} = Invoicing.create_invoice(business, @valid_attrs)

      assert first.invoice_number == "INV-0001"
      assert second.invoice_number == "INV-0002"
    end

    test "rejects missing line_items", %{business: business} do
      attrs = Map.delete(@valid_attrs, "line_items")
      assert {:error, :line_items_required} = Invoicing.create_invoice(business, attrs)
    end

    test "rejects an empty line_items list", %{business: business} do
      attrs = Map.put(@valid_attrs, "line_items", [])
      assert {:error, :line_items_required} = Invoicing.create_invoice(business, attrs)
    end

    test "rejects a line item with zero quantity", %{business: business} do
      attrs = Map.put(@valid_attrs, "line_items", [%{"description" => "x", "quantity" => 0, "unit_price" => "10"}])
      assert {:error, :invalid_line_item} = Invoicing.create_invoice(business, attrs)
    end

    test "rejects a line item with negative unit_price", %{business: business} do
      attrs = Map.put(@valid_attrs, "line_items", [%{"description" => "x", "quantity" => 1, "unit_price" => "-5"}])
      assert {:error, :invalid_line_item} = Invoicing.create_invoice(business, attrs)
    end

    test "rejects due_date before issue_date", %{business: business} do
      attrs = Map.put(@valid_attrs, "due_date", "2026-08-01")
      assert {:error, changeset} = Invoicing.create_invoice(business, attrs)
      assert "cannot be before the issue date" in errors_on(changeset).due_date
    end
  end

  describe "get_invoice_for_business/2" do
    test "returns nil for an invoice belonging to a different business", %{business: business} do
      {:ok, other_user} =
        Accounts.register_user(%{"phone_number" => "0700111222", "password" => "supersecret"})

      {:ok, other_business} = Businesses.create_business(other_user, %{"business_name" => "Other Co"})
      {:ok, invoice} = Invoicing.create_invoice(other_business, @valid_attrs)

      assert Invoicing.get_invoice_for_business(business, invoice.id) == nil
    end

    test "returns nil for a garbage id string rather than raising", %{business: business} do
      assert Invoicing.get_invoice_for_business(business, "not-a-uuid") == nil
    end
  end

  describe "update_invoice/3" do
    test "updates scalar fields on a draft without touching line items", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)

      assert {:ok, updated} = Invoicing.update_invoice(business, invoice.id, %{"buyer_name" => "New Name"})
      assert updated.buyer_name == "New Name"
      assert length(updated.line_items) == 2
      assert Decimal.equal?(updated.total, invoice.total)
    end

    test "replaces line items and recomputes totals when line_items is included", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)

      new_items = [%{"description" => "Just one thing", "quantity" => 1, "unit_price" => "1000.00"}]
      assert {:ok, updated} = Invoicing.update_invoice(business, invoice.id, %{"line_items" => new_items})

      assert length(updated.line_items) == 1
      assert Decimal.equal?(updated.total, Decimal.new("1000.00"))
    end

    test "returns :not_editable once the invoice is sent", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      {:ok, _sent} = Invoicing.send_invoice(business, invoice.id)

      assert {:error, :not_editable} = Invoicing.update_invoice(business, invoice.id, %{"buyer_name" => "x"})
    end

    test "returns :not_found for a nonexistent invoice", %{business: business} do
      assert {:error, :not_found} = Invoicing.update_invoice(business, Ecto.UUID.generate(), %{"buyer_name" => "x"})
    end
  end

  describe "status transitions" do
    test "send_invoice/2 moves draft to sent and sets sent_at", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      assert {:ok, sent} = Invoicing.send_invoice(business, invoice.id)

      assert sent.status == "sent"
      refute is_nil(sent.sent_at)
    end

    test "send_invoice/2 rejects a non-draft invoice", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      {:ok, _} = Invoicing.send_invoice(business, invoice.id)

      assert {:error, :invalid_transition} = Invoicing.send_invoice(business, invoice.id)
    end

    test "mark_paid/2 moves sent to paid and sets paid_at", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      {:ok, _} = Invoicing.send_invoice(business, invoice.id)

      assert {:ok, paid} = Invoicing.mark_paid(business, invoice.id)
      assert paid.status == "paid"
      refute is_nil(paid.paid_at)
    end

    test "mark_paid/2 rejects a draft invoice (must be sent first)", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      assert {:error, :invalid_transition} = Invoicing.mark_paid(business, invoice.id)
    end

    test "cancel_invoice/2 works from draft", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      assert {:ok, cancelled} = Invoicing.cancel_invoice(business, invoice.id)
      assert cancelled.status == "cancelled"
    end

    test "cancel_invoice/2 works from sent", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      {:ok, _} = Invoicing.send_invoice(business, invoice.id)

      assert {:ok, cancelled} = Invoicing.cancel_invoice(business, invoice.id)
      assert cancelled.status == "cancelled"
    end

    test "cancel_invoice/2 rejects an already-paid invoice", %{business: business} do
      {:ok, invoice} = Invoicing.create_invoice(business, @valid_attrs)
      {:ok, _} = Invoicing.send_invoice(business, invoice.id)
      {:ok, _} = Invoicing.mark_paid(business, invoice.id)

      assert {:error, :invalid_transition} = Invoicing.cancel_invoice(business, invoice.id)
    end
  end

  describe "overdue?/1" do
    test "a sent invoice past its due date is overdue", %{business: business} do
      attrs =
        @valid_attrs
        |> Map.put("issue_date", Date.utc_today() |> Date.add(-10) |> Date.to_iso8601())
        |> Map.put("due_date", Date.utc_today() |> Date.add(-1) |> Date.to_iso8601())

      {:ok, invoice} = Invoicing.create_invoice(business, attrs)
      {:ok, sent} = Invoicing.send_invoice(business, invoice.id)

      assert Invoicing.overdue?(sent)
    end

    test "a draft invoice past its due date is NOT overdue (only sent invoices can be)", %{business: business} do
      attrs =
        @valid_attrs
        |> Map.put("issue_date", Date.utc_today() |> Date.add(-10) |> Date.to_iso8601())
        |> Map.put("due_date", Date.utc_today() |> Date.add(-1) |> Date.to_iso8601())

      {:ok, invoice} = Invoicing.create_invoice(business, attrs)

      refute Invoicing.overdue?(invoice)
    end

    test "a sent invoice not yet past due date is not overdue", %{business: business} do
      attrs =
        @valid_attrs
        |> Map.put("issue_date", Date.utc_today() |> Date.to_iso8601())
        |> Map.put("due_date", Date.utc_today() |> Date.add(14) |> Date.to_iso8601())

      {:ok, invoice} = Invoicing.create_invoice(business, attrs)
      {:ok, sent} = Invoicing.send_invoice(business, invoice.id)

      refute Invoicing.overdue?(sent)
    end
  end
end
