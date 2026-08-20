defmodule Lipaharaka.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LipaharakaWeb.Telemetry,
      Lipaharaka.Repo,
      {Phoenix.PubSub, name: Lipaharaka.PubSub},
      # Start the endpoint last, once everything else is running
      LipaharakaWeb.Endpoint
      # Step 3 will add: {Oban, Application.fetch_env!(:lipaharaka, Oban)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lipaharaka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LipaharakaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
