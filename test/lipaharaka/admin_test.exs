defmodule Lipaharaka.AdminTest do
  use Lipaharaka.DataCase, async: false

  alias Lipaharaka.{Accounts, Admin, Businesses}

  setup do
    Lipaharaka.SMS.Test.clear()
    {:ok, user} = Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})
    {:ok, business} = Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
    %{business: business, user: user}
  end

  defp upload_document(business, document_type) do
    path = Path.join(System.tmp_dir!(), "admin_test_#{System.unique_integer([:positive])}.jpg")
    File.write!(path, "fake file contents")
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    upload = %Plug.Upload{path: path, filename: "doc.jpg", content_type: "image/jpeg"}
    {:ok, document} = Businesses.upload_kyc_document(business, document_type, upload)
    document
  end

  describe "list_pending_kyc_documents/0" do
    test "returns documents with status pending, preloaded with business and user", %{business: business} do
      upload_document(business, "national_id")

      [document] = Admin.list_pending_kyc_documents()
      assert document.status == "pending"
      assert document.business.id == business.id
      assert document.business.user.phone_number == "+254712345678"
    end

    test "does not return already-reviewed documents", %{business: business} do
      document = upload_document(business, "national_id")
      {:ok, _} = Admin.review_kyc_document(document.id, "approved")

      assert Admin.list_pending_kyc_documents() == []
    end
  end

  describe "review_kyc_document/3" do
    test "approving a document sets its status and reviewed_at", %{business: business} do
      document = upload_document(business, "national_id")

      assert {:ok, reviewed} = Admin.review_kyc_document(document.id, "approved", "looks good")
      assert reviewed.status == "approved"
      assert reviewed.review_note == "looks good"
      refute is_nil(reviewed.reviewed_at)
    end

    test "returns :invalid_decision for anything other than approved/rejected" do
      assert {:error, :invalid_decision} = Admin.review_kyc_document(Ecto.UUID.generate(), "maybe")
    end

    test "returns :not_found for a nonexistent document id" do
      assert {:error, :not_found} = Admin.review_kyc_document(Ecto.UUID.generate(), "approved")
    end

    test "approving the only document sets the business kyc_status to approved", %{business: business, user: user} do
      document = upload_document(business, "national_id")
      {:ok, reviewed} = Admin.review_kyc_document(document.id, "approved")

      assert reviewed.business.kyc_status == "approved"
      assert Businesses.get_business_for_user(user).kyc_status == "approved"
    end

    test "rejecting one document sets the business kyc_status to rejected even if others are approved", %{business: business} do
      doc1 = upload_document(business, "national_id")
      doc2 = upload_document(business, "kra_pin_certificate")

      {:ok, _} = Admin.review_kyc_document(doc1.id, "approved")
      {:ok, reviewed2} = Admin.review_kyc_document(doc2.id, "rejected")

      assert reviewed2.business.kyc_status == "rejected"
    end

    test "business kyc_status stays pending while some documents are still unreviewed", %{business: business} do
      doc1 = upload_document(business, "national_id")
      _doc2 = upload_document(business, "kra_pin_certificate")

      {:ok, reviewed1} = Admin.review_kyc_document(doc1.id, "approved")

      assert reviewed1.business.kyc_status == "pending"
    end
  end

  describe "list_businesses/0" do
    test "returns businesses with user preloaded", %{business: business} do
      [found] = Admin.list_businesses()
      assert found.id == business.id
      assert found.user.phone_number == "+254712345678"
    end
  end
end
