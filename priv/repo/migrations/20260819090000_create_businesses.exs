defmodule Lipaharaka.Repo.Migrations.CreateBusinesses do
  use Ecto.Migration

  def change do
    create table(:businesses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :business_name, :string, null: false
      add :registration_number, :string
      add :kra_pin, :string
      add :sector, :string
      add :mpesa_till_or_paybill, :string


      add :kyc_status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end


    create unique_index(:businesses, [:user_id])
  end
end
