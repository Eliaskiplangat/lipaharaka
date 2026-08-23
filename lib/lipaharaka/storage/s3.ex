defmodule Lipaharaka.Storage.S3 do
  @moduledoc """
  Real object storage adapter using S3-compatible storage via ExAws.

  Deliberately works with any S3-compatible provider, not just AWS —
  set `:host`/`:scheme`/`:port` in the `:ex_aws, :s3` config to point
  at DigitalOcean Spaces, MinIO (self-hosted, good for a VPS-based
  deploy), Cloudflare R2, Backblaze B2, or real AWS S3.

  Required config:

      config :lipaharaka, :kyc_bucket, "your-bucket-name"

      config :ex_aws,
        access_key_id: "...",
        secret_access_key: "...",
        region: "..."

      config :ex_aws, :s3,
        host: "s3.amazonaws.com",   # or e.g. "nyc3.digitaloceanspaces.com"
        scheme: "https://",
        region: "..."

  The bucket MUST be private — this adapter uploads with no ACL
  override (bucket's default, which should be block-all-public), and
  every read goes through a short-lived presigned URL rather than a
  permanent public link. KYC documents (national IDs, KRA PIN
  certificates, etc.) should never be reachable by a bare URL.
  """

  @behaviour Lipaharaka.Storage

  @presigned_url_expiry_seconds 900

  @impl true
  def put(key, binary, content_type) do
    bucket = Application.fetch_env!(:lipaharaka, :kyc_bucket)

    bucket
    |> ExAws.S3.put_object(key, binary, content_type: content_type)
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 200}} -> {:ok, key}
      {:ok, response} -> {:error, {:unexpected_response, response}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def download_url(key) do
    bucket = Application.fetch_env!(:lipaharaka, :kyc_bucket)
    config = ExAws.Config.new(:s3)

    case ExAws.S3.presigned_url(config, :get, bucket, key, expires_in: @presigned_url_expiry_seconds) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end
end
