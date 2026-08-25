defmodule LipaharakaWeb.Admin.KycDocumentController do
  use LipaharakaWeb, :controller

  alias Lipaharaka.Admin

  @moduledoc """
  Runs behind the `:admin` pipeline (RequireAuth then RequireAdmin —
  see router.ex). Every action here can see and act on any business's
  documents, unlike `LipaharakaWeb.KycDocumentController`, which is
  scoped to the current user's own business only.
  """

  @doc "GET /api/admin/kyc_documents/pending"
  def pending(conn, _params) do
    documents = Admin.list_pending_kyc_documents()
    render(conn, :pending, documents: documents)
  end

  @doc """
  PATCH /api/admin/kyc_documents/:id

  Body: {"decision": "approved" | "rejected", "review_note": "..." (optional)}
  """
  def review(conn, %{"id" => id, "decision" => decision} = params) do
    review_note = Map.get(params, "review_note")

    case Admin.review_kyc_document(id, decision, review_note) do
      {:ok, document} ->
        render(conn, :reviewed, document: document)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{document: "not found"}})

      {:error, :invalid_decision} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{decision: "must be \"approved\" or \"rejected\""}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  def review(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "decision is required"}})
  end
end
