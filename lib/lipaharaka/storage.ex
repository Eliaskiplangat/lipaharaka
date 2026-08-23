defmodule Lipaharaka.Storage do
  @moduledoc """
  Thin dispatcher over a configurable object storage adapter, so the
  rest of the application never talks to S3 (or any storage backend)
  directly — it calls `Lipaharaka.Storage.put/3` and `download_url/1`.

  The adapter is chosen via config:

      config :lipaharaka, :storage_adapter, Lipaharaka.Storage.S3

  Two adapters exist:

    * `Lipaharaka.Storage.S3` — the real integration, used in
      production. Uploads to a **private** bucket (KYC documents are
      sensitive — national IDs, KRA PIN certificates — and are never
      served from a public URL) and returns short-lived presigned URLs
      for download.
    * `Lipaharaka.Storage.Local` — writes to a local directory instead.
      Default in `dev` and `test`, so the KYC upload flow works
      end-to-end without needing S3/MinIO credentials just to keep
      developing.

  Keys are chosen by the caller (see
  `Lipaharaka.Businesses.upload_kyc_document/3`) and should be
  treated as opaque, unguessable identifiers — never sequential IDs —
  since knowing a key is part of what the presigned-URL model relies
  on for the Local adapter's dev-mode convenience methods, and it's
  simply good practice regardless of adapter.
  """

  @type key :: String.t()
  @type content_type :: String.t()

  @callback put(key(), binary(), content_type()) :: {:ok, key()} | {:error, term()}
  @callback download_url(key()) :: {:ok, String.t()} | {:error, term()}

  @spec put(key(), binary(), content_type()) :: {:ok, key()} | {:error, term()}
  def put(key, binary, content_type), do: adapter().put(key, binary, content_type)

  @spec download_url(key()) :: {:ok, String.t()} | {:error, term()}
  def download_url(key), do: adapter().download_url(key)

  defp adapter do
    Application.get_env(:lipaharaka, :storage_adapter, Lipaharaka.Storage.Local)
  end
end
