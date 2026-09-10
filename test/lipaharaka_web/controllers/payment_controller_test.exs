defmodule LipaharakaWeb.PaymentControllerTest do
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
    Lipaharaka.Mpesa.Test.clear()

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

  describe "POST /api/invoices/:id/request_payment" do
    test "returns 422 for a draft invoice", %{conn: conn, invoice: invoice} do
      conn = post(conn, ~p"/api/invoices/#{invoice.id}/request_payment")
      assert json_response(conn, 422)
    end

    test "initiates payment for a sent invoice", %{conn: conn, business: business, invoice: invoice} do
      Invoicing.send_invoice(business, invoice.id)

      conn = post(conn, ~p"/api/invoices/#{invoice.id}/request_payment")
      assert %{"payment" => payment} = json_response(conn, 201)
      assert payment["status"] == "pending"
      refute is_nil(payment["checkout_request_id"])
    end

    test "returns 401 without a token" do
      conn = Phoenix.ConnTest.build_conn()
      conn = post(conn, ~p"/api/invoices/#{Ecto.UUID.generate()}/request_payment")
      assert json_response(conn, 401)
    end
  end
end
