defmodule LipaharakaWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such as controllers and views.

  This can be used in your application as:

      use LipaharakaWeb, :controller

  The definitions below will be executed for every controller,
  so keep them short and clean, focused on imports, uses and aliases.
  """

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:json],
        layouts: []

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: LipaharakaWeb.Endpoint,
        router: LipaharakaWeb.Router,
        statics: []
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/router/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
