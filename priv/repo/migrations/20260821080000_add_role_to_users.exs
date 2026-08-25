defmodule Lipaharaka.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # sme | admin — never settable by the client at registration.
      # Promoting a user to admin is, deliberately, not exposed as an
      # API endpoint yet (no self-service admin signup) — done via
      # iex or a direct DB update for now. See README Step 6.
      add :role, :string, null: false, default: "sme"
    end
  end
end
