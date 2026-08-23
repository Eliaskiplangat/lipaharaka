import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is the best place to load production secrets
# and configuration from environment variables.

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :lipaharaka, Lipaharaka.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :lipaharaka, LipaharakaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  # ## Africa's Talking SMS credentials — required in production.
  # Get these from your Africa's Talking dashboard: https://account.africastalking.com
  config :lipaharaka, :sms_adapter, Lipaharaka.SMS.AfricasTalking

  config :lipaharaka, :africas_talking,
    username: System.fetch_env!("AFRICASTALKING_USERNAME"),
    api_key: System.fetch_env!("AFRICASTALKING_API_KEY"),
    sender_id: System.get_env("AFRICASTALKING_SENDER_ID"),
    base_url: System.get_env("AFRICASTALKING_BASE_URL") || "https://api.africastalking.com"

  # ## S3-compatible object storage credentials — required in production.
  # Works with AWS S3, DigitalOcean Spaces, MinIO, Cloudflare R2, etc.
  # — just point S3_HOST at the right endpoint for your provider.
  config :lipaharaka, :storage_adapter, Lipaharaka.Storage.S3
  config :lipaharaka, :kyc_bucket, System.fetch_env!("S3_KYC_BUCKET")

  config :ex_aws,
    access_key_id: System.fetch_env!("S3_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("S3_SECRET_ACCESS_KEY"),
    region: System.get_env("S3_REGION") || "us-east-1"

  config :ex_aws, :s3,
    host: System.get_env("S3_HOST") || "s3.amazonaws.com",
    scheme: System.get_env("S3_SCHEME") || "https://",
    region: System.get_env("S3_REGION") || "us-east-1"

  # ## M-Pesa Daraja API credentials (used from Step 4 onward)
  # config :lipaharaka, :mpesa,
  #   consumer_key: System.fetch_env!("MPESA_CONSUMER_KEY"),
  #   consumer_secret: System.fetch_env!("MPESA_CONSUMER_SECRET"),
  #   shortcode: System.fetch_env!("MPESA_SHORTCODE"),
  #   passkey: System.fetch_env!("MPESA_PASSKEY")
end
