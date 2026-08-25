defmodule LipaharakaWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug for admin-only routes. Must run AFTER `RequireAuth` (see the
  `:admin` router pipeline, which composes `:authenticated` then
  this) — it reads `conn.assigns.current_user`, which `RequireAuth` is
  responsible for setting.

  Distinguishes "not logged in" (401, from `RequireAuth`, which runs
  first) from "logged in but not an admin" (403, from here) — these
  are genuinely different situations and the status code should say
  so.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{current_user: %{role: "admin"}}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{errors: %{detail: "admin access required"}})
    |> halt()
  end
end
