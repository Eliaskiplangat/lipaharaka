import Config

# Configure your database
config :lipaharaka, Lipaharaka.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "127.0.0.1",
  port: 5433,
  database: "lipaharaka_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :lipaharaka, LipaharakaWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_bytes_long_CHANGE_ME_1234567890",
  server: true

# SMS defaults to the Console adapter in dev, so the OTP flow works
# end-to-end without needing a live Africa's Talking account. Switch
# this to Lipaharaka.SMS.AfricasTalking (and fill in :africas_talking
# below) once you have sandbox credentials and want to test real SMS.
config :lipaharaka, :sms_adapter, Lipaharaka.SMS.Console

# config :lipaharaka, :africas_talking,
#   username: "sandbox",
#   api_key: "your-sandbox-api-key",
#   base_url: "https://api.sandbox.africastalking.com"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Storage defaults to Local in dev — writes to priv/uploads/, no S3
# account needed to develop the KYC upload flow. Switch to
# Lipaharaka.Storage.S3 (and fill in the config below) once you have
# S3-compatible credentials (AWS, DigitalOcean Spaces, MinIO, etc.)
# and want to test real uploads.
config :lipaharaka, :storage_adapter, Lipaharaka.Storage.Local
config :lipaharaka, :local_storage_path, "priv/uploads"

# config :lipaharaka, :storage_adapter, Lipaharaka.Storage.S3
# config :lipaharaka, :kyc_bucket, "lipaharaka-kyc-dev"
# config :ex_aws,
#   access_key_id: "your-access-key",
#   secret_access_key: "your-secret-key",
#   region: "us-east-1"
# config :ex_aws, :s3,
#   host: "s3.amazonaws.com",  # or e.g. "nyc3.digitaloceanspaces.com" for Spaces
#   scheme: "https://",
#   region: "us-east-1"
