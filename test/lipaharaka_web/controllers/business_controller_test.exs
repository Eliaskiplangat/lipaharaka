defmodule LipaharakaWeb.BusinessControllerTest do
  use LipaharakaWeb.ConnCase, async: false

  alias Lipaharaka.Accounts

  @valid_attrs %{
    "business_name" => "Jaza Traders Ltd",
    "registration_number" => "BN-2024-001",
    "kra_pin" => "A123456789Z",
    "sector" => "Retail",
    "mpesa_till_or_paybill" => "174379"
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

  describe "POST /api/businesses" do
    test "creates a business for the authenticated user", %{conn: conn} do
      conn = post(conn, ~p"/api/businesses", @valid_attrs)

      assert %{"business" => business} = json_response(conn, 201)
      assert business["business_name"] == "Jaza Traders Ltd"
      assert business["kyc_status"] == "pending"
    end

    test "returns 401 without a token", %{} do
      conn = Phoenix.ConnTest.build_conn()
      conn = post(conn, ~p"/api/businesses", @valid_attrs)
      assert json_response(conn, 401)
    end

    test "returns 422 when business_name is missing", %{conn: conn} do
      attrs = Map.delete(@valid_attrs, "business_name")
      conn = post(conn, ~p"/api/businesses", attrs)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["business_name"]
    end

    test "returns 409 if the user already has a business", %{conn: conn} do
      post(conn, ~p"/api/businesses", @valid_attrs)
      conn2 = post(conn, ~p"/api/businesses", @valid_attrs)

      assert json_response(conn2, 409)
    end
  end

  describe "GET /api/businesses/me" do
    test "returns 404 when the user has no business yet", %{conn: conn} do
      conn = get(conn, ~p"/api/businesses/me")
      assert json_response(conn, 404)
    end

    test "returns the business once created", %{conn: conn} do
      post(conn, ~p"/api/businesses", @valid_attrs)
      conn2 = get(conn, ~p"/api/businesses/me")

      assert %{"business" => business} = json_response(conn2, 200)
      assert business["business_name"] == "Jaza Traders Ltd"
    end
  end

  describe "PATCH /api/businesses/me" do
    test "updates the business", %{conn: conn} do
      post(conn, ~p"/api/businesses", @valid_attrs)
      conn2 = patch(conn, ~p"/api/businesses/me", %{"sector" => "Wholesale"})

      assert %{"business" => business} = json_response(conn2, 200)
      assert business["sector"] == "Wholesale"
    end

    test "returns 404 if the user has no business yet", %{conn: conn} do
      conn = patch(conn, ~p"/api/businesses/me", %{"sector" => "Wholesale"})
      assert json_response(conn, 404)
    end
  end
end
