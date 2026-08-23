defmodule LipaharakaWeb.KycDocumentControllerTest do
  use LipaharakaWeb.ConnCase, async: false

  alias Lipaharaka.Accounts

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

  defp temp_upload(content \\ "fake file contents") do
    path = Path.join(System.tmp_dir!(), "lipaharaka_ctrl_test_#{System.unique_integer([:positive])}.jpg")
    File.write!(path, content)
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    %Plug.Upload{path: path, filename: "id.jpg", content_type: "image/jpeg"}
  end

  describe "POST /api/businesses/me/kyc_documents" do
    test "returns 404 if the user has no business yet", %{conn: conn} do
      conn =
        post(conn, ~p"/api/businesses/me/kyc_documents", %{
          "document_type" => "national_id",
          "file" => temp_upload()
        })

      assert json_response(conn, 404)
    end

    test "uploads a document once the user has a business", %{conn: conn} do
      post(conn, ~p"/api/businesses", %{"business_name" => "Jaza Traders Ltd"})

      conn =
        post(conn, ~p"/api/businesses/me/kyc_documents", %{
          "document_type" => "national_id",
          "file" => temp_upload()
        })

      assert %{"document" => document} = json_response(conn, 201)
      assert document["document_type"] == "national_id"
      assert document["status"] == "pending"
      assert document["download_url"]
    end

    test "returns 422 for an invalid document_type", %{conn: conn} do
      post(conn, ~p"/api/businesses", %{"business_name" => "Jaza Traders Ltd"})

      conn =
        post(conn, ~p"/api/businesses/me/kyc_documents", %{
          "document_type" => "passport",
          "file" => temp_upload()
        })

      assert %{"errors" => %{"document" => message}} = json_response(conn, 422)
      assert message =~ "invalid document_type"
    end

    test "returns 401 without a token" do
      conn = Phoenix.ConnTest.build_conn()

      conn =
        post(conn, ~p"/api/businesses/me/kyc_documents", %{
          "document_type" => "national_id",
          "file" => temp_upload()
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/businesses/me/kyc_documents" do
    test "returns an empty list before any upload", %{conn: conn} do
      post(conn, ~p"/api/businesses", %{"business_name" => "Jaza Traders Ltd"})

      conn = get(conn, ~p"/api/businesses/me/kyc_documents")
      assert %{"documents" => []} = json_response(conn, 200)
    end

    test "returns uploaded documents", %{conn: conn} do
      post(conn, ~p"/api/businesses", %{"business_name" => "Jaza Traders Ltd"})

      post(conn, ~p"/api/businesses/me/kyc_documents", %{
        "document_type" => "national_id",
        "file" => temp_upload()
      })

      conn = get(conn, ~p"/api/businesses/me/kyc_documents")
      assert %{"documents" => [document]} = json_response(conn, 200)
      assert document["document_type"] == "national_id"
    end
  end
end
