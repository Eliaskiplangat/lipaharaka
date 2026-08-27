defmodule LipaharakaWeb.InvoiceControllerTest do
  use LipaharakaWeb.ConnCase, async: false

  alias Lipaharaka.{Accounts, Businesses}

  @valid_attrs %{
    "buyer_name" => "Zuri Retail Ltd",
    "buyer_phone" => "0798765432",
    "issue_date" => "2026-08-12",
    "due_date" => "2026-08-26",
    "line_items" => [
      %{"description" => "Office desks", "quantity" => 8, "unit_price" => "6500.00"}
    ]
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
    token = LipaharakaWeb.Auth.Token.sign(user.id)
    authed_conn = put_req_header(conn, "authorization", "Bearer " <> token)

    %{conn: authed_conn, user: user}
  end

  describe "POST /api/invoices" do
    test "returns 404 if the user has no business yet", %{conn: conn} do
      conn = post(conn, ~p"/api/invoices", @valid_attrs)
      assert json_response(conn, 404)
    end

    test "creates an invoice once the user has a business", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})

      conn = post(conn, ~p"/api/invoices", @valid_attrs)

      assert %{"invoice" => invoice} = json_response(conn, 201)
      assert invoice["invoice_number"] == "INV-0001"
      assert invoice["status"] == "draft"
      assert invoice["total"] == "52000.00"
      assert length(invoice["line_items"]) == 1
    end

    test "returns 422 with no line items", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
      attrs = Map.delete(@valid_attrs, "line_items")

      conn = post(conn, ~p"/api/invoices", attrs)
      assert %{"errors" => %{"line_items" => _}} = json_response(conn, 422)
    end

    test "returns 401 without a token" do
      conn = Phoenix.ConnTest.build_conn()
      conn = post(conn, ~p"/api/invoices", @valid_attrs)
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/invoices and /api/invoices/:id" do
    test "lists and fetches invoices scoped to the user's business", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
      %{"invoice" => created} = post(conn, ~p"/api/invoices", @valid_attrs) |> json_response(201)

      index_conn = get(conn, ~p"/api/invoices")
      assert %{"invoices" => [_one]} = json_response(index_conn, 200)

      show_conn = get(conn, ~p"/api/invoices/#{created["id"]}")
      assert %{"invoice" => shown} = json_response(show_conn, 200)
      assert shown["id"] == created["id"]
    end

    test "returns 404 for another business's invoice", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})

      {:ok, other_user} =
        Accounts.register_user(%{"phone_number" => "0700111222", "password" => "supersecret"})

      {:ok, other_business} = Businesses.create_business(other_user, %{"business_name" => "Other Co"})
      {:ok, other_invoice} = Lipaharaka.Invoicing.create_invoice(other_business, @valid_attrs)

      conn = get(conn, ~p"/api/invoices/#{other_invoice.id}")
      assert json_response(conn, 404)
    end
  end

  describe "PATCH /api/invoices/:id" do
    test "updates a draft invoice", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
      %{"invoice" => created} = post(conn, ~p"/api/invoices", @valid_attrs) |> json_response(201)

      conn = patch(conn, ~p"/api/invoices/#{created["id"]}", %{"buyer_name" => "Renamed Ltd"})
      assert %{"invoice" => updated} = json_response(conn, 200)
      assert updated["buyer_name"] == "Renamed Ltd"
    end

    test "returns 422 once the invoice has been sent", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
      %{"invoice" => created} = post(conn, ~p"/api/invoices", @valid_attrs) |> json_response(201)
      post(conn, ~p"/api/invoices/#{created["id"]}/send", %{})

      conn = patch(conn, ~p"/api/invoices/#{created["id"]}", %{"buyer_name" => "x"})
      assert json_response(conn, 422)
    end
  end

  describe "status transition endpoints" do
    test "send then mark_paid moves an invoice through its lifecycle", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
      %{"invoice" => created} = post(conn, ~p"/api/invoices", @valid_attrs) |> json_response(201)
      id = created["id"]

      send_conn = post(conn, ~p"/api/invoices/#{id}/send", %{})
      assert %{"invoice" => %{"status" => "sent"}} = json_response(send_conn, 200)

      paid_conn = post(conn, ~p"/api/invoices/#{id}/mark_paid", %{})
      assert %{"invoice" => %{"status" => "paid"}} = json_response(paid_conn, 200)
    end

    test "mark_paid before send returns 422", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
      %{"invoice" => created} = post(conn, ~p"/api/invoices", @valid_attrs) |> json_response(201)

      conn = post(conn, ~p"/api/invoices/#{created["id"]}/mark_paid", %{})
      assert json_response(conn, 422)
    end

    test "cancel works on a draft invoice", %{conn: conn, user: user} do
      Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
      %{"invoice" => created} = post(conn, ~p"/api/invoices", @valid_attrs) |> json_response(201)

      conn = post(conn, ~p"/api/invoices/#{created["id"]}/cancel", %{})
      assert %{"invoice" => %{"status" => "cancelled"}} = json_response(conn, 200)
    end
  end
end
