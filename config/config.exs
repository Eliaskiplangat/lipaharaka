import Config

config :lipaharaka,
  ecto_repos: [Lipaharaka.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :lipaharaka, LipaharakaWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: LipaharakaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Lipaharaka.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Background jobs — used by the invoice reminder engine
# (Lipaharaka.Reminders). Environment-specific overrides (test mode,
# queue behaviour) live in config/test.exs.
config :lipaharaka, Oban,
  repo: Lipaharaka.Repo,
  plugins: [{Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}],
  queues: [reminders: 10]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
