defmodule LipaharakaWeb.PaymentController do
  use LipaharakaWeb, :controller

  alias Lipaharaka.{Businesses, Payments}

  @moduledoc """
  Runs behind `:authenticated`. `request_payment/2` first resolves
  the current user's own business — there is no route or action here
  that takes a business id from the client.
  """

  @doc "POST /api/invoices/:id/request_payment"
  def request_payment(conn, %{"id" => id}) do
    case Businesses.get_business_for_user(conn.assigns.current_user) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{business: "you have not registered a business yet"}})

      business ->
        case Payments.request_payment(business, id) do
          {:ok, payment} ->
            conn
            |> put_status(:created)
            |> render(:show, payment: payment)

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{errors: %{invoice: "not found"}})

          {:error, :invalid_invoice_status} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: %{invoice: "must be sent before requesting payment"}})

          {:error, {:mpesa_request_failed, _reason}} ->
            conn
            |> put_status(:bad_gateway)
            |> json(%{errors: %{detail: "could not initiate M-Pesa payment, please try again"}})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:changeset_error, changeset: changeset)
        end
    end
  end
end
