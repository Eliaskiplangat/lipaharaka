import Config


config :lipaharaka, Lipaharaka.Repo,
  username: "postgres",
  password: "elias",
  hostname: "localhost",
  database: "lipaharaka_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: 5433,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2


config :lipaharaka, LipaharakaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_CHANGE_ME_1234567890",
  server: false


config :lipaharaka, :sms_adapter, Lipaharaka.SMS.Test


config :bcrypt_elixir, :log_rounds, 4

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
