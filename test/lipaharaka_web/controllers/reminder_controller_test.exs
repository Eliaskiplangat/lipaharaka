defmodule LipaharakaWeb.ReminderControllerTest do
  use LipaharakaWeb.ConnCase, async: false

  alias Lipaharaka.{Accounts, Businesses, Invoicing}

  @invoice_attrs %{
    "buyer_name" => "Zuri Retail Ltd",
    "buyer_phone" => "0798765432",
    "issue_date" => "2026-08-12",
    "due_date" => "2026-08-26",
    "line_items" => [%{"description" => "Office desks", "quantity" => 8, "unit_price" => "6500.00"}]
  }

  setup %{conn: conn} do
    Lipaharaka.SMS.Test.clear()

    {:ok, user} =
      Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})

    otp =
      "+254712345678"
      |> Lipaharaka.SMS.Test.last_message_to()
      |> then(&Regex.run(~r/\d{6}/, &1))
      |> hd()

    {:ok, user} = Accounts.verify_otp(user.phone_number, otp)
    {:ok, business} = Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
    {:ok, invoice} = Invoicing.create_invoice(business, @invoice_attrs)

    token = LipaharakaWeb.Auth.Token.sign(user.id)
    authed_conn = put_req_header(conn, "authorization", "Bearer " <> token)

    %{conn: authed_conn, business: business, invoice: invoice}
  end

  describe "GET /api/invoices/:invoice_id/reminders" do
    test "returns an empty list before the invoice is sent (nothing scheduled yet)", %{
      conn: conn,
      invoice: invoice
    } do
      conn = get(conn, ~p"/api/invoices/#{invoice.id}/reminders")
      assert %{"reminders" => []} = json_response(conn, 200)
    end

    test "returns the scheduled reminders once the invoice is sent", %{
      conn: conn,
      business: business,
      invoice: invoice
    } do
      Invoicing.send_invoice(business, invoice.id)

      conn = get(conn, ~p"/api/invoices/#{invoice.id}/reminders")
      assert %{"reminders" => reminders} = json_response(conn, 200)
      assert length(reminders) == length(Lipaharaka.Reminders.offsets())
      assert Enum.all?(reminders, &(&1["status"] == "scheduled"))
    end

    test "returns 404 for another business's invoice", %{conn: conn} do
      {:ok, other_user} =
        Accounts.register_user(%{"phone_number" => "0700111222", "password" => "supersecret"})

      {:ok, other_business} = Businesses.create_business(other_user, %{"business_name" => "Other Co"})
      {:ok, other_invoice} = Invoicing.create_invoice(other_business, @invoice_attrs)

      conn = get(conn, ~p"/api/invoices/#{other_invoice.id}/reminders")
      assert json_response(conn, 404)
    end

    test "returns 401 without a token" do
      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, ~p"/api/invoices/#{Ecto.UUID.generate()}/reminders")
      assert json_response(conn, 401)
    end
  end
end
