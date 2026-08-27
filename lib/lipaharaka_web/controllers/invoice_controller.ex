defmodule LipaharakaWeb.InvoiceController do
  use LipaharakaWeb, :controller

  alias Lipaharaka.{Businesses, Invoicing}

  @moduledoc """
  Runs behind `:authenticated`. Every action first resolves the
  current user's own business — there is no route or action here that
  takes a business id from the client, and `Invoicing` itself never
  fetches an invoice without a business to scope to (see its
  moduledoc), so there is no path from this controller to another
  business's invoices.
  """

  @doc "POST /api/invoices"
  def create(conn, params) do
    with_business(conn, fn business ->
      case Invoicing.create_invoice(business, params) do
        {:ok, invoice} ->
          conn
          |> put_status(:created)
          |> render(:show, invoice: invoice)

        {:error, reason} ->
          render_error(conn, reason)
      end
    end)
  end

  @doc "GET /api/invoices"
  def index(conn, _params) do
    with_business(conn, fn business ->
      invoices = Invoicing.list_invoices_for_business(business)
      render(conn, :index, invoices: invoices)
    end)
  end

  @doc "GET /api/invoices/:id"
  def show(conn, %{"id" => id}) do
    with_business(conn, fn business ->
      case Invoicing.get_invoice_for_business(business, id) do
        nil -> not_found(conn)
        invoice -> render(conn, :show, invoice: invoice)
      end
    end)
  end

  @doc "PATCH /api/invoices/:id"
  def update(conn, %{"id" => id} = params) do
    with_business(conn, fn business ->
      case Invoicing.update_invoice(business, id, params) do
        {:ok, invoice} -> render(conn, :show, invoice: invoice)
        {:error, reason} -> render_error(conn, reason)
      end
    end)
  end

  @doc "POST /api/invoices/:id/send"
  def send_invoice(conn, %{"id" => id}) do
    with_business(conn, fn business ->
      case Invoicing.send_invoice(business, id) do
        {:ok, invoice} -> render(conn, :show, invoice: invoice)
        {:error, reason} -> render_error(conn, reason)
      end
    end)
  end

  @doc """
  POST /api/invoices/:id/mark_paid

  Manual for now — see `Lipaharaka.Invoicing.mark_paid/2` moduledoc.
  """
  def mark_paid(conn, %{"id" => id}) do
    with_business(conn, fn business ->
      case Invoicing.mark_paid(business, id) do
        {:ok, invoice} -> render(conn, :show, invoice: invoice)
        {:error, reason} -> render_error(conn, reason)
      end
    end)
  end

  @doc "POST /api/invoices/:id/cancel"
  def cancel(conn, %{"id" => id}) do
    with_business(conn, fn business ->
      case Invoicing.cancel_invoice(business, id) do
        {:ok, invoice} -> render(conn, :show, invoice: invoice)
        {:error, reason} -> render_error(conn, reason)
      end
    end)
  end

  defp with_business(conn, fun) do
    case Businesses.get_business_for_user(conn.assigns.current_user) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{business: "you have not registered a business yet"}})

      business ->
        fun.(business)
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{invoice: "not found"}})
  end

  defp render_error(conn, :not_found), do: not_found(conn)

  defp render_error(conn, :not_editable) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{invoice: "cannot be edited once it is no longer a draft"}})
  end

  defp render_error(conn, :invalid_transition) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{invoice: "cannot perform this action in the invoice's current status"}})
  end

  defp render_error(conn, :line_items_required) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{line_items: "at least one line item is required"}})
  end

  defp render_error(conn, :invalid_line_item) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      errors: %{
        line_items: "each line item needs a description, a positive quantity, and a non-negative unit_price"
      }
    })
  end

  defp render_error(conn, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:changeset_error, changeset: changeset)
  end
end
