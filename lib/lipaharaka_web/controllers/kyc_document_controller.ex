defmodule LipaharakaWeb.KycDocumentController do
  use LipaharakaWeb, :controller

  alias Lipaharaka.Businesses

  @moduledoc """
  Runs behind `:authenticated`. Every action first resolves the
  current user's own business — there is no route or action here that
  takes a business id from the client, so there's no way to upload to
  or list another business's documents.
  """

  @doc """
  POST /api/businesses/me/kyc_documents

  Multipart form fields: `document_type` (string) and `file` (the
  upload itself). Re-uploading the same document_type replaces the
  existing one.
  """
  def create(conn, %{"document_type" => document_type, "file" => %Plug.Upload{} = upload}) do
    with %Businesses.Business{} = business <- Businesses.get_business_for_user(conn.assigns.current_user),
         {:ok, document} <- Businesses.upload_kyc_document(business, document_type, upload) do
      conn
      |> put_status(:created)
      |> render(:show, document: document)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{business: "you have not registered a business yet"}})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:upload_error, reason: reason)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "document_type and file are required"}})
  end

  @doc """
  GET /api/businesses/me/kyc_documents

  Lists the current user's business's documents, each with a fresh,
  short-lived download URL.
  """
  def index(conn, _params) do
    case Businesses.get_business_for_user(conn.assigns.current_user) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{business: "you have not registered a business yet"}})

      business ->
        documents = Businesses.list_kyc_documents(business)
        render(conn, :index, documents: documents)
    end
  end
end
