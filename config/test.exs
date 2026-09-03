import Config

# Configure your database
config :lipaharaka, Lipaharaka.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "127.0.0.1",
  port: 5433,
  database: "lipaharaka_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lipaharaka, LipaharakaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_CHANGE_ME_1234567890",
  server: false

# Use the Test adapter so tests can assert on sent messages (and read
# OTP codes back out of them) without hitting a real SMS provider.
config :lipaharaka, :sms_adapter, Lipaharaka.SMS.Test

# Speed up tests significantly — bcrypt's whole point is being slow,
# but that's wasted time in a test suite that hashes hundreds of times.
config :bcrypt_elixir, :log_rounds, 4

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Storage uses Local in test too, but pointed at a separate directory
# so test uploads never collide with anything written during dev.
config :lipaharaka, :storage_adapter, Lipaharaka.Storage.Local
config :lipaharaka, :local_storage_path, "priv/uploads_test"

# Oban: manual testing mode — jobs are inserted into the database
# (so we can assert they were enqueued correctly) but never actually
# picked up and run by a background queue. Tests that need a job's
# *effect* call the underlying context function directly
# (Reminders.deliver_reminder/1), not Oban's scheduler — see
# test/lipaharaka/reminders_test.exs.
config :lipaharaka, Oban, testing: :manual, queues: false, plugins: false
