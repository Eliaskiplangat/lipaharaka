defmodule LipaharakaWeb.Plugs.RequireAdminTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias LipaharakaWeb.Plugs.RequireAdmin

  test "passes through when current_user has role admin" do
    conn =
      :get
      |> conn("/")
      |> Plug.Conn.assign(:current_user, %{role: "admin"})
      |> RequireAdmin.call([])

    refute conn.halted
  end

  test "halts with 403 when current_user is not an admin" do
    conn =
      :get
      |> conn("/")
      |> Plug.Conn.assign(:current_user, %{role: "sme"})
      |> RequireAdmin.call([])

    assert conn.halted
    assert conn.status == 403
  end

  test "halts with 403 when there is no current_user assigned at all" do
    conn =
      :get
      |> conn("/")
      |> RequireAdmin.call([])

    assert conn.halted
    assert conn.status == 403
  end
end
