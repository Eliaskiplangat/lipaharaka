defmodule Lipaharaka.Repo do
  use Ecto.Repo,
    otp_app: :lipaharaka,
    adapter: Ecto.Adapters.Postgres
end
