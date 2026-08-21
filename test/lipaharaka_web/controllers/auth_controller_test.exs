defmodule LipaharakaWeb.AuthControllerTest do
  use LipaharakaWeb.ConnCase, async: false

  setup do
    Lipaharaka.SMS.Test.clear()
    :ok
  end

  describe "POST /api/auth/register" do
    test "registers a user and returns 201", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", %{
          "phone_number" => "0712345678",
          "password" => "supersecret"
        })

      assert %{"user" => user, "message" => _} = json_response(conn, 201)
      assert user["phone_number"] == "+254712345678"
      assert user["phone_verified"] == false
    end

    test "returns 422 for an invalid phone number", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", %{
          "phone_number" => "not-a-phone",
          "password" => "supersecret"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["phone_number"]
    end
  end

  describe "POST /api/auth/verify_otp" do
    test "verifies with the correct code and returns a token", %{conn: conn} do
      conn1 =
        post(conn, ~p"/api/auth/register", %{
          "phone_number" => "0712345678",
          "password" => "supersecret"
        })

      json_response(conn1, 201)

      otp = extract_otp("+254712345678")

      conn2 =
        post(conn, ~p"/api/auth/verify_otp", %{
          "phone_number" => "0712345678",
          "otp" => otp
        })

      assert %{"user" => user, "token" => token} = json_response(conn2, 200)
      assert user["phone_verified"] == true
      assert is_binary(token) and byte_size(token) > 0
    end

    test "returns 422 for an incorrect code", %{conn: conn} do
      post(conn, ~p"/api/auth/register", %{
        "phone_number" => "0712345678",
        "password" => "supersecret"
      })

      conn2 =
        post(conn, ~p"/api/auth/verify_otp", %{
          "phone_number" => "0712345678",
          "otp" => "000000"
        })

      assert %{"errors" => %{"otp" => _}} = json_response(conn2, 422)
    end
  end

  describe "POST /api/auth/login" do
    test "logs in once phone is verified and returns a token", %{conn: conn} do
      post(conn, ~p"/api/auth/register", %{
        "phone_number" => "0712345678",
        "password" => "supersecret"
      })

      otp = extract_otp("+254712345678")
      post(conn, ~p"/api/auth/verify_otp", %{"phone_number" => "0712345678", "otp" => otp})

      conn2 =
        post(conn, ~p"/api/auth/login", %{
          "phone_number" => "0712345678",
          "password" => "supersecret"
        })

      assert %{"user" => user, "token" => token} = json_response(conn2, 200)
      assert user["phone_verified"] == true
      assert is_binary(token) and byte_size(token) > 0
    end

    test "returns 403 if phone not yet verified", %{conn: conn} do
      post(conn, ~p"/api/auth/register", %{
        "phone_number" => "0712345678",
        "password" => "supersecret"
      })

      conn2 =
        post(conn, ~p"/api/auth/login", %{
          "phone_number" => "0712345678",
          "password" => "supersecret"
        })

      assert json_response(conn2, 403)
    end

    test "returns 401 for wrong password", %{conn: conn} do
      post(conn, ~p"/api/auth/register", %{
        "phone_number" => "0712345678",
        "password" => "supersecret"
      })

      conn2 =
        post(conn, ~p"/api/auth/login", %{
          "phone_number" => "0712345678",
          "password" => "wrongpassword"
        })

      assert json_response(conn2, 401)
    end
  end

  describe "GET /api/me" do
    setup %{conn: conn} do
      post(conn, ~p"/api/auth/register", %{
        "phone_number" => "0712345678",
        "password" => "supersecret"
      })

      otp = extract_otp("+254712345678")

      verify_conn =
        post(conn, ~p"/api/auth/verify_otp", %{"phone_number" => "0712345678", "otp" => otp})

      %{"token" => token, "user" => user} = json_response(verify_conn, 200)

      %{token: token, user_id: user["id"]}
    end

    test "returns the current user with a valid token", %{conn: conn, token: token, user_id: user_id} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get(~p"/api/me")

      assert %{"user" => %{"id" => ^user_id}} = json_response(conn, 200)
    end

    test "returns 401 with no Authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/me")
      assert %{"errors" => %{"detail" => detail}} = json_response(conn, 401)
      assert detail =~ "missing"
    end

    test "returns 401 with a garbage token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-a-real-token")
        |> get(~p"/api/me")

      assert %{"errors" => %{"detail" => detail}} = json_response(conn, 401)
      assert detail =~ "invalid"
    end
  end

  defp extract_otp(phone_number) do
    phone_number
    |> Lipaharaka.SMS.Test.last_message_to()
    |> then(&Regex.run(~r/\d{6}/, &1))
    |> hd()
  end
end
