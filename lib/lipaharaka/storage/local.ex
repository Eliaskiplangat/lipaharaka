defmodule Lipaharaka.Storage.Local do
  @moduledoc """
  Development/test storage adapter: writes files to a local directory
  instead of S3.

  Default in `dev` and `test`, so the KYC upload flow — file received,
  stored, listed back with a download link — works end-to-end without
  needing real (or even MinIO/local S3-compatible) credentials just to
  keep developing. Switch to `Lipaharaka.Storage.S3` in `config/dev.exs`
  once you want to test against real S3-compatible storage; production
  (`config/runtime.exs`) already uses `S3` unconditionally.

  Files are written under `Application.get_env(:lipaharaka,
  :local_storage_path, "priv/uploads")`. `download_url/1` returns a
  `file://` path rather than an HTTP URL, since there's no web server
  in front of this directory — good enough for local development and
  for tests to verify a file round-trips correctly, but not something
  a real frontend should ever be given.
  """

  @behaviour Lipaharaka.Storage

  @impl true
  def put(key, binary, _content_type) do
    path = full_path(key)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, binary)
    {:ok, key}
  rescue
    e -> {:error, e}
  end

  @impl true
  def download_url(key) do
    path = full_path(key)

    if File.exists?(path) do
      {:ok, "file://" <> Path.expand(path)}
    else
      {:error, :not_found}
    end
  end

  defp full_path(key) do
    base = Application.get_env(:lipaharaka, :local_storage_path, "priv/uploads")
    Path.join(base, key)
  end
end
