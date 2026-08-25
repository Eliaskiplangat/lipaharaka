defmodule LipaharakaWeb.Admin.KycDocumentControllerTest do
  use LipaharakaWeb.ConnCase, async: false

  alias Lipaharaka.{Accounts, Businesses}

  defp register_and_verify(phone) do
    Lipaharaka.SMS.Test.clear()
    {:ok, user} = Accounts.register_user(%{"phone_number" => phone, "password" => "supersecret"})

    otp =
      user.phone_number
      |> Lipaharaka.SMS.Test.last_message_to()
      |> then(&Regex.run(~r/\d{6}/, &1))
      |> hd()

    {:ok, user} = Accounts.verify_otp(user.phone_number, otp)
    user
  end

  defp upload_document(business, document_type) do
    path = Path.join(System.tmp_dir!(), "admin_ctrl_test_#{System.unique_integer([:positive])}.jpg")
    File.write!(path, "fake file contents")
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    upload = %Plug.Upload{path: path, filename: "doc.jpg", content_type: "image/jpeg"}
    {:ok, document} = Businesses.upload_kyc_document(business, document_type, upload)
    document
  end

  setup %{conn: conn} do
    sme = register_and_verify("0712345678")
    {:ok, business} = Businesses.create_business(sme, %{"business_name" => "Jaza Traders Ltd"})

    admin = register_and_verify("0700000000")
    {:ok, admin} = Accounts.promote_to_admin(admin)

    sme_token = LipaharakaWeb.Auth.Token.sign(sme.id)
    admin_token = LipaharakaWeb.Auth.Token.sign(admin.id)

    %{
      conn: conn,
      sme_conn: put_req_header(conn, "authorization", "Bearer " <> sme_token),
      admin_conn: put_req_header(conn, "authorization", "Bearer " <> admin_token),
      business: business
    }
  end

  describe "GET /api/admin/kyc_documents/pending" do
    test "returns 401 with no token", %{conn: conn} do
      conn = get(conn, ~p"/api/admin/kyc_documents/pending")
      assert json_response(conn, 401)
    end

    test "returns 403 for a non-admin user", %{sme_conn: conn} do
      conn = get(conn, ~p"/api/admin/kyc_documents/pending")
      assert json_response(conn, 403)
    end

    test "returns pending documents for an admin", %{admin_conn: conn, business: business} do
      upload_document(business, "national_id")

      conn = get(conn, ~p"/api/admin/kyc_documents/pending")
      assert %{"documents" => [document]} = json_response(conn, 200)
      assert document["document_type"] == "national_id"
      assert document["business"]["business_name"] == "Jaza Traders Ltd"
    end
  end

  describe "PATCH /api/admin/kyc_documents/:id" do
    test "returns 403 for a non-admin user", %{sme_conn: conn, business: business} do
      document = upload_document(business, "national_id")

      conn = patch(conn, ~p"/api/admin/kyc_documents/#{document.id}", %{"decision" => "approved"})
      assert json_response(conn, 403)
    end

    test "approves a document and updates the business kyc_status", %{admin_conn: conn, business: business} do
      document = upload_document(business, "national_id")

      conn =
        patch(conn, ~p"/api/admin/kyc_documents/#{document.id}", %{
          "decision" => "approved",
          "review_note" => "all good"
        })

      assert %{"document" => reviewed} = json_response(conn, 200)
      assert reviewed["status"] == "approved"
      assert reviewed["review_note"] == "all good"
      assert reviewed["business"]["kyc_status"] == "approved"
    end

    test "returns 422 for an invalid decision", %{admin_conn: conn, business: business} do
      document = upload_document(business, "national_id")

      conn = patch(conn, ~p"/api/admin/kyc_documents/#{document.id}", %{"decision" => "maybe"})
      assert json_response(conn, 422)
    end

    test "returns 404 for a nonexistent document", %{admin_conn: conn} do
      conn =
        patch(conn, ~p"/api/admin/kyc_documents/#{Ecto.UUID.generate()}", %{"decision" => "approved"})

      assert json_response(conn, 404)
    end
  end
end
