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
      {Oban, Application.fetch_env!(:lipaharaka, Oban)},
      # These two are the in-memory "Test" adapters for SMS and
      # M-Pesa. Starting them here, as supervised children, is
      # deliberate — NOT an oversight of "why are test doubles in
      # production's supervision tree." They used to be lazily
      # started on first use from inside whichever process touched
      # them first, which included individual ExUnit test processes.
      # Agent.start_link/2 LINKS the caller, so a lazily-started Agent
      # was accidentally linked to a transient test process — if that
      # unrelated test process ever crashed, the link took the shared
      # Agent down with it, breaking every subsequent test that
      # depended on it. Supervising them from boot means they're
      # linked to the supervisor instead, immune to unrelated process
      # crashes. They're harmless, idle processes when the configured
      # adapter is the real SMS/AfricasTalking or Mpesa/Daraja one.
      Lipaharaka.SMS.Test,
      Lipaharaka.Mpesa.Test,
      # Start the endpoint last, once everything else is running
      LipaharakaWeb.Endpoint
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
