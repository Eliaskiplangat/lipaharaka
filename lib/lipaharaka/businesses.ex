defmodule Lipaharaka.Businesses do
  @moduledoc """
  The Businesses context: SME business profile creation/management,
  and KYC document upload.

  As with Accounts, controllers should call into this module rather
  than touching `Lipaharaka.Businesses.{Business,KycDocument}`/`Repo`
  directly.

  Every function here that could act on a business or its documents
  takes the authenticated `Lipaharaka.Accounts.User` (or the `Business`
  already scoped to them) explicitly — there is no function in this
  module that fetches "a business by business id" or "a document by
  document id" alone, on purpose. That would make it too easy for a
  future controller to accidentally let one user look up or modify
  another user's business or documents. If/when we build Admin review
  (FR-1.4) and genuinely need "any business/document by id", that'll
  be a deliberately separate, clearly-named function such as
  `get_business_for_admin/1` — not a reuse of these.
  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Storage
  alias Lipaharaka.Accounts.User
  alias Lipaharaka.Businesses.{Business, KycDocument}

  @doc """
  Creates a business owned by the given user.

  Returns `{:error, :already_exists}` if the user already has a
  business (see the one-business-per-user constraint), or
  `{:error, changeset}` for other validation failures.
  """
  @spec create_business(User.t(), map()) ::
          {:ok, Business.t()} | {:error, :already_exists | Ecto.Changeset.t()}
  def create_business(%User{} = user, attrs) do
    changeset =
      %Business{user_id: user.id}
      |> Business.create_changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, business} ->
        {:ok, business}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if Keyword.has_key?(errors, :user_id) do
          {:error, :already_exists}
        else
          {:error, changeset}
        end
    end
  end

  @doc "Fetches the given user's business, or `nil` if they haven't registered one."
  @spec get_business_for_user(User.t()) :: Business.t() | nil
  def get_business_for_user(%User{} = user) do
    Repo.get_by(Business, user_id: user.id)
  end

  @doc """
  Updates the given user's business profile.

  Returns `{:error, :not_found}` if they don't have a business yet,
  or `{:error, changeset}` for validation failures.
  """
  @spec update_business(User.t(), map()) ::
          {:ok, Business.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_business(%User{} = user, attrs) do
    case get_business_for_user(user) do
      nil ->
        {:error, :not_found}

      business ->
        business
        |> Business.update_changeset(attrs)
        |> Repo.update()
    end
  end

  # ============================================================
  # KYC Documents
  # ============================================================

  @doc """
  Uploads a KYC document for the given business. `upload` is a
  `%Plug.Upload{}`, as Phoenix provides for multipart form fields.

  Validates document type, content type, and file size BEFORE
  touching storage, so we never upload something we're going to
  reject anyway. Returns a distinct error atom for each validation
  failure (`:invalid_document_type`, `:invalid_content_type`,
  `:file_too_large`, `:empty_file`) so the controller can render a
  specific message for each, the same pattern used for OTP errors in
  `Lipaharaka.Accounts`.

  If the business already has a document of this type, it is
  **replaced in place** (same storage key, overwritten) rather than
  accumulating duplicates, and its status resets to `"pending"` since
  a new file needs to be reviewed again.
  """
  @spec upload_kyc_document(Business.t(), String.t(), Plug.Upload.t()) ::
          {:ok, KycDocument.t()}
          | {:error,
             :invalid_document_type
             | :invalid_content_type
             | :file_too_large
             | :empty_file
             | {:storage_failed, term()}
             | Ecto.Changeset.t()}
  def upload_kyc_document(%Business{} = business, document_type, %Plug.Upload{} = upload) do
    with :ok <- validate_document_type(document_type),
         {:ok, content_type} <- validate_content_type(upload.content_type),
         {:ok, size} <- validate_file_size(upload.path),
         {:ok, binary} <- File.read(upload.path) do
      existing = get_kyc_document_by_type(business, document_type)

      storage_key =
        if existing, do: existing.storage_key, else: build_storage_key(business, document_type, upload.filename)

      case Storage.put(storage_key, binary, content_type) do
        {:ok, ^storage_key} ->
          attrs = %{
            business_id: business.id,
            document_type: document_type,
            storage_key: storage_key,
            original_filename: upload.filename,
            content_type: content_type,
            file_size_bytes: size
          }

          upsert_kyc_document(existing, attrs)

        {:error, reason} ->
          {:error, {:storage_failed, reason}}
      end
    end
  end

  @doc """
  Lists the given business's KYC documents, ordered by document type.
  Does NOT include a download URL — call `kyc_document_download_url/1`
  separately for a given document when one is actually needed, since
  presigned URLs are short-lived and shouldn't be generated for
  documents nobody's about to look at.
  """
  @spec list_kyc_documents(Business.t()) :: [KycDocument.t()]
  def list_kyc_documents(%Business{} = business) do
    Repo.all(from d in KycDocument, where: d.business_id == ^business.id, order_by: d.document_type)
  end

  @doc "Generates a fresh, short-lived download URL for a KYC document."
  @spec kyc_document_download_url(KycDocument.t()) :: {:ok, String.t()} | {:error, term()}
  def kyc_document_download_url(%KycDocument{} = document) do
    Storage.download_url(document.storage_key)
  end

  @doc """
  Recomputes and persists a business's `kyc_status` from the current
  state of its KYC documents:

    * `"rejected"` if any document has been rejected
    * `"approved"` if at least one document exists and all are approved
    * `"pending"` otherwise (no documents yet, or some still pending)

  Called automatically by `Lipaharaka.Admin.review_kyc_document/3`
  after a document review — not meant to be called directly from a
  controller.
  """
  @spec refresh_kyc_status(Business.t()) :: {:ok, Business.t()} | {:error, Ecto.Changeset.t()}
  def refresh_kyc_status(%Business{} = business) do
    documents = list_kyc_documents(business)

    status =
      cond do
        documents == [] -> "pending"
        Enum.any?(documents, &(&1.status == "rejected")) -> "rejected"
        Enum.all?(documents, &(&1.status == "approved")) -> "approved"
        true -> "pending"
      end

    business
    |> Business.kyc_status_changeset(status)
    |> Repo.update()
  end

  defp upsert_kyc_document(nil, attrs) do
    %KycDocument{}
    |> KycDocument.create_changeset(attrs)
    |> Repo.insert()
  end

  defp upsert_kyc_document(%KycDocument{} = existing, attrs) do
    existing
    |> KycDocument.create_changeset(attrs)
    |> Ecto.Changeset.put_change(:status, "pending")
    |> Ecto.Changeset.put_change(:reviewed_at, nil)
    |> Ecto.Changeset.put_change(:review_note, nil)
    |> Repo.update()
  end

  defp get_kyc_document_by_type(business, document_type) do
    Repo.get_by(KycDocument, business_id: business.id, document_type: document_type)
  end

  defp validate_document_type(type) do
    if type in KycDocument.document_types(), do: :ok, else: {:error, :invalid_document_type}
  end

  defp validate_content_type(content_type) do
    if content_type in KycDocument.allowed_content_types() do
      {:ok, content_type}
    else
      {:error, :invalid_content_type}
    end
  end

  defp validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: 0}} ->
        {:error, :empty_file}

      {:ok, %{size: size}} ->
        if size > KycDocument.max_file_size_bytes() do
          {:error, :file_too_large}
        else
          {:ok, size}
        end

      {:error, reason} ->
        {:error, {:file_read_error, reason}}
    end
  end

  defp build_storage_key(business, document_type, filename) do
    ext = Path.extname(filename)
    "kyc/#{business.id}/#{document_type}#{ext}"
  end
end
