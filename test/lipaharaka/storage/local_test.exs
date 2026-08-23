defmodule Lipaharaka.Storage.LocalTest do
  use ExUnit.Case, async: false

  alias Lipaharaka.Storage.Local

  @test_path "priv/uploads_test_unit"

  setup do
    Application.put_env(:lipaharaka, :local_storage_path, @test_path)
    on_exit(fn -> File.rm_rf!(@test_path) end)
    :ok
  end

  test "put/3 writes a file and returns the key" do
    assert {:ok, "some/key.pdf"} = Local.put("some/key.pdf", "hello world", "application/pdf")
    assert File.read!(Path.join(@test_path, "some/key.pdf")) == "hello world"
  end

  test "download_url/1 returns a file:// URL for an existing key" do
    Local.put("doc.pdf", "content", "application/pdf")

    assert {:ok, url} = Local.download_url("doc.pdf")
    assert String.starts_with?(url, "file://")
    assert url =~ "doc.pdf"
  end

  test "download_url/1 returns :not_found for a missing key" do
    assert {:error, :not_found} = Local.download_url("nonexistent.pdf")
  end

  test "put/3 creates nested directories as needed" do
    assert {:ok, _} = Local.put("kyc/business-123/national_id.pdf", "data", "application/pdf")
    assert File.exists?(Path.join(@test_path, "kyc/business-123/national_id.pdf"))
  end
end
