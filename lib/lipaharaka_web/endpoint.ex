defmodule LipaharakaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :lipaharaka

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_lipaharaka_key",
    signing_salt: "CHANGE_ME_SIGNING_SALT",
    same_site: "Lax"
  ]

  # Serve at "/" the static files from "priv/static" directory.
  # Not needed yet for an API-only app, kept here as a placeholder
  # for when we add e.g. served PDFs/receipts in a later step.
  # plug Plug.Static,
  #   at: "/",
  #   from: :lipaharaka,
  #   gzip: false

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug LipaharakaWeb.Router
end
