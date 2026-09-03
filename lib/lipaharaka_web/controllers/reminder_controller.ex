defmodule LipaharakaWeb.ReminderController do
  use LipaharakaWeb, :controller

  alias Lipaharaka.{Businesses, Reminders}

  @moduledoc """
  Runs behind `:authenticated`. Reminder history for a single invoice,
  scoped through the current user's own business — see
  `Lipaharaka.Reminders.list_reminders_for_invoice/2`.
  """

  @doc "GET /api/invoices/:invoice_id/reminders"
  def index(conn, %{"invoice_id" => invoice_id}) do
    case Businesses.get_business_for_user(conn.assigns.current_user) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{business: "you have not registered a business yet"}})

      business ->
        case Reminders.list_reminders_for_invoice(business, invoice_id) do
          {:ok, reminders} ->
            render(conn, :index, reminders: reminders)

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{errors: %{invoice: "not found"}})
        end
    end
  end
end
