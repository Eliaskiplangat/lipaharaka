defmodule LipaharakaWeb.HealthControllerTest do
  use LipaharakaWeb.ConnCase, async: true

  test "GET /api/health returns ok status", %{conn: conn} do
    conn = get(conn, ~p"/api/health")

    assert %{"status" => "ok", "service" => "lipaharaka"} = json_response(conn, 200)
  end
end
