defmodule Lipaharaka.BusinessesKycTest do
  use Lipaharaka.DataCase, async: false

  alias Lipaharaka.{Accounts, Businesses}

  @business_attrs %{"business_name" => "Jaza Traders Ltd"}

  setup do
    Lipaharaka.SMS.Test.clear()
    {:ok, user} = Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})
    {:ok, business} = Businesses.create_business(user, @business_attrs)
    %{business: business}
  end

  defp temp_upload(content \\ "fake file contents", filename \\ "id.jpg", content_type \\ "image/jpeg") do
    path = Path.join(System.tmp_dir!(), "lipaharaka_test_#{System.unique_integer([:positive])}#{Path.extname(filename)}")
    File.write!(path, content)
    on_exit_delete(path)
    %Plug.Upload{path: path, filename: filename, content_type: content_type}
  end

  defp on_exit_delete(path) do
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
  end

  describe "upload_kyc_document/3" do
    test "uploads and stores a document", %{business: business} do
      upload = temp_upload()

      assert {:ok, document} = Businesses.upload_kyc_document(business, "national_id", upload)
      assert document.business_id == business.id
      assert document.document_type == "national_id"
      assert document.status == "pending"
      assert document.file_size_bytes > 0
    end

    test "rejects an invalid document_type", %{business: business} do
      upload = temp_upload()
      assert {:error, :invalid_document_type} = Businesses.upload_kyc_document(business, "passport", upload)
    end

    test "rejects an invalid content_type", %{business: business} do
      upload = temp_upload("some data", "file.exe", "application/x-msdownload")
      assert {:error, :invalid_content_type} = Businesses.upload_kyc_document(business, "national_id", upload)
    end

    test "rejects an empty file", %{business: business} do
      upload = temp_upload("")
      assert {:error, :empty_file} = Businesses.upload_kyc_document(business, "national_id", upload)
    end

    test "rejects a file over the size limit", %{business: business} do
      big_content = :binary.copy("a", 6 * 1024 * 1024)
      upload = temp_upload(big_content)
      assert {:error, :file_too_large} = Businesses.upload_kyc_document(business, "national_id", upload)
    end

    test "re-uploading the same document_type replaces it, resetting status", %{business: business} do
      {:ok, first} = Businesses.upload_kyc_document(business, "national_id", temp_upload("first version"))

      # Simulate it having been reviewed before the re-upload
      first
      |> Ecto.Changeset.change(status: "approved")
      |> Lipaharaka.Repo.update!()

      {:ok, second} =
        Businesses.upload_kyc_document(business, "national_id", temp_upload("second version"))

      assert second.id == first.id
      assert second.status == "pending"
      assert [only_one] = Businesses.list_kyc_documents(business)
      assert only_one.id == first.id
    end
  end

  describe "list_kyc_documents/1" do
    test "returns an empty list when none uploaded", %{business: business} do
      assert Businesses.list_kyc_documents(business) == []
    end

    test "returns uploaded documents ordered by type", %{business: business} do
      Businesses.upload_kyc_document(business, "national_id", temp_upload())
      Businesses.upload_kyc_document(business, "kra_pin_certificate", temp_upload())

      types = business |> Businesses.list_kyc_documents() |> Enum.map(& &1.document_type)
      assert types == Enum.sort(types)
      assert length(types) == 2
    end
  end

  describe "kyc_document_download_url/1" do
    test "returns a download URL for an uploaded document", %{business: business} do
      {:ok, document} = Businesses.upload_kyc_document(business, "national_id", temp_upload())
      assert {:ok, url} = Businesses.kyc_document_download_url(document)
      assert is_binary(url)
    end
  end
end
