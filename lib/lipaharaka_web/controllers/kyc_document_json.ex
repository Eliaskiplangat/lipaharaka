defmodule LipaharakaWeb.KycDocumentJSON do
  alias Lipaharaka.Businesses
  alias Lipaharaka.Businesses.KycDocument

  def show(%{document: document}) do
    %{document: document_summary(document)}
  end

  def index(%{documents: documents}) do
    %{documents: Enum.map(documents, &document_summary/1)}
  end

  def upload_error(%{reason: reason}) do
    %{errors: %{document: upload_error_message(reason)}}
  end

  defp upload_error_message(:invalid_document_type) do
    "invalid document_type — must be one of: " <> Enum.join(KycDocument.document_types(), ", ")
  end

  defp upload_error_message(:invalid_content_type) do
    "invalid file type — must be one of: " <> Enum.join(KycDocument.allowed_content_types(), ", ")
  end

  defp upload_error_message(:file_too_large) do
    max_mb = div(KycDocument.max_file_size_bytes(), 1024 * 1024)
    "file too large — maximum #{max_mb}MB"
  end

  defp upload_error_message(:empty_file), do: "file is empty"
  defp upload_error_message({:storage_failed, _reason}), do: "upload failed, please try again"

  defp upload_error_message(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc -> String.replace(acc, "%{#{key}}", to_string(value)) end)
    end)
    |> inspect()
  end

  defp upload_error_message(_), do: "upload failed"

  defp document_summary(%KycDocument{} = document) do
    download_url =
      case Businesses.kyc_document_download_url(document) do
        {:ok, url} -> url
        {:error, _reason} -> nil
      end

    %{
      id: document.id,
      document_type: document.document_type,
      original_filename: document.original_filename,
      content_type: document.content_type,
      file_size_bytes: document.file_size_bytes,
      status: document.status,
      review_note: document.review_note,
      download_url: download_url,
      uploaded_at: document.inserted_at
    }
  end
end
