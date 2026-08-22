defmodule LipaharakaWeb.BusinessController do
  use LipaharakaWeb, :controller

  alias Lipaharaka.Businesses


  def create(conn, params) do
    case Businesses.create_business(conn.assigns.current_user, params) do
      {:ok, business} ->
        conn
        |> put_status(:created)
        |> render(:show, business: business)

      {:error, :already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{errors: %{business: "you already have a registered business"}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset_error, changeset: changeset)
    end
  end


  def show(conn, _params) do
    case Businesses.get_business_for_user(conn.assigns.current_user) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{business: "you have not registered a business yet"}})

      business ->
        render(conn, :show, business: business)
    end
  end


  def update(conn, params) do
    case Businesses.update_business(conn.assigns.current_user, params) do
      {:ok, business} ->
        render(conn, :show, business: business)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{business: "you have not registered a business yet"}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset_error, changeset: changeset)
    end
  end
end
