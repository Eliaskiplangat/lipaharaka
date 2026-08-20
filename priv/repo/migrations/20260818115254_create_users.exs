defmodule Lipaharaka.Repo.Migrations.CreateBusinesses do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone_number, :string, null: false
      add :password_hash, :string, null: false
      add :phone_verified_at, :utc_datetime
      add :otp_hash, :string
      add :otp_expires_at, :utc_datetime
      add :otp_attempts, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:phone_number])
  end
