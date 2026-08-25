defmodule Lipaharaka.Admin do
  @moduledoc """
  The Admin context: cross-business operations for platform staff.

  This is the one deliberate exception to the "never fetch by raw ID"
  rule that `Lipaharaka.Businesses` follows — every function here IS
  the admin boundary. Every call site that reaches this module is
  already required to have passed through both `RequireAuth` and
  `RequireAdmin` (see the `:admin` router pipeline), so by the time
  code executes here, the caller has already been proven to be an
  authenticated platform admin, not an arbitrary SME.
  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Businesses
  alias Lipaharaka.Businesses.{Business, KycDocument}

  @doc """
  Lists all KYC documents currently awaiting review, each preloaded
  with its business (and the business's owning user), ordered oldest
  first — so the review queue is naturally FIFO.
  """
  @spec list_pending_kyc_documents() :: [KycDocument.t()]
  def list_pending_kyc_documents do
    Repo.all(
      from d in KycDocument,
        where: d.status == "pending",
        order_by: [asc: d.inserted_at],
        preload: [business: :user]
    )
  end

  @doc """
  Fetches a single KYC document by id, preloaded with its business and
  owning user, or `nil`. Only meaningful from within this admin
  context — see the moduledoc.
  """
  @spec get_kyc_document(Ecto.UUID.t()) :: KycDocument.t() | nil
  def get_kyc_document(id) do
    Repo.get(KycDocument, id) |> Repo.preload(business: :user)
  end

  @doc """
  Reviews a KYC document: sets its status to `"approved"` or
  `"rejected"` with an optional note, then recomputes the parent
  business's overall `kyc_status` to match
  (`Lipaharaka.Businesses.refresh_kyc_status/1`).

  Returns `{:ok, document}` (with the business preloaded and
  reflecting its updated `kyc_status`) or `{:error, reason}`.
  """
  @spec review_kyc_document(Ecto.UUID.t(), String.t(), String.t() | nil) ::
          {:ok, KycDocument.t()} | {:error, :not_found | :invalid_decision | Ecto.Changeset.t()}
  def review_kyc_document(document_id, decision, review_note \\ nil)

  def review_kyc_document(_document_id, decision, _review_note)
      when decision not in ~w(approved rejected) do
    {:error, :invalid_decision}
  end

  def review_kyc_document(document_id, decision, review_note) do
    case get_kyc_document(document_id) do
      nil ->
        {:error, :not_found}

      document ->
        with {:ok, updated_document} <-
               document
               |> KycDocument.review_changeset(decision, review_note)
               |> Repo.update(),
             {:ok, updated_business} <- Businesses.refresh_kyc_status(document.business) do
          {:ok, %{updated_document | business: updated_business}}
        end
    end
  end

  @doc "Lists all businesses, most recently created first — for a future Admin dashboard."
  @spec list_businesses() :: [Business.t()]
  def list_businesses do
    Repo.all(from b in Business, order_by: [desc: b.inserted_at], preload: :user)
  end
end
