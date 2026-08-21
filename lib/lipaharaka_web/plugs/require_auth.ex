defmodule LipaharakaWeb.Plugs.RequireAuth do

  import Plug.Conn
  alias Lipaharaka.Accounts
  alias LipaharakaWeb.Auth.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- fetch_bearer_token(conn),
         {:ok, user_id} <- Token.verify(token),
         %Accounts.User{} = user <- Accounts.get_user(user_id) do
      assign(conn, :current_user, user)
    else
      {:error, :missing} -> unauthorized(conn, "missing Authorization header")
      {:error, :expired} -> unauthorized(conn, "token expired, please log in again")
      {:error, :invalid} -> unauthorized(conn, "invalid token")
      nil -> unauthorized(conn, "user no longer exists")
    end
  end

  defp fetch_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing}
    end
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{errors: %{detail: message}})
    |> halt()
  end
end
