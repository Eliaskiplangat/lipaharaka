defmodule LipaharakaWeb.ConnCase do


  use ExUnit.CaseTemplate

  using do
    quote do

      @endpoint LipaharakaWeb.Endpoint

      use LipaharakaWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import LipaharakaWeb.ConnCase
    end
  end

  setup tags do
    Lipaharaka.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
