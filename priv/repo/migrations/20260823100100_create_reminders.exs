defmodule Lipaharaka.Repo.Migrations.CreateReminders do
  use Ecto.Migration

  def change do
    create table(:reminders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all), null: false


      add :offset_days, :integer, null: false
      add :scheduled_for, :date, null: false


      add :status, :string, null: false, default: "scheduled"
      add :channel, :string, null: false, default: "sms"
      add :message, :text
      add :sent_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:reminders, [:invoice_id])
    create index(:reminders, [:status])
  end
end
