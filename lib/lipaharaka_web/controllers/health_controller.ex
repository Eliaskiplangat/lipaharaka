defmodule LipaharakaWeb.HealthController do
  use LipaharakaWeb, :controller

  @moduledoc """
  A simple liveness/readiness endpoint: GET /api/health

  This exists in Step 1 purely so we have something real to run and
  hit with curl to confirm the skeleton boots correctly, before we
  add any real business logic.
  """

  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      service: "lipaharaka",
      version: Application.spec(:lipaharaka, :vsn) |> to_string()
    })
  end
end
