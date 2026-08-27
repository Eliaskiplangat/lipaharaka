defmodule Lipaharaka.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :business_id, references(:businesses, type: :binary_id, on_delete: :delete_all), null: false

      # Human-readable, sequential per business (e.g. "INV-0001"). See
      # Lipaharaka.Invoicing moduledoc for a note on why this is not
      # guaranteed collision-free under concurrent creation yet.
      add :invoice_number, :string, null: false

      add :buyer_name, :string, null: false
      add :buyer_phone, :string, null: false
      add :buyer_email, :string

      add :issue_date, :date, null: false
      add :due_date, :date, null: false

      # draft | sent | paid | cancelled. "overdue" is deliberately NOT
      # a stored status — it's computed at read time from due_date, so
      # there's no background job required to keep it accurate.
      add :status, :string, null: false, default: "draft"

      # All monetary fields are decimal, never float, to avoid
      # rounding errors — and always server-computed from line items,
      # never trusted directly from the client.
      add :subtotal, :decimal, null: false, default: 0
      add :tax_rate, :decimal, null: false, default: 0
      add :tax_amount, :decimal, null: false, default: 0
      add :total, :decimal, null: false, default: 0

      add :notes, :string

      add :sent_at, :utc_datetime
      add :paid_at, :utc_datetime
      add :cancelled_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:invoices, [:business_id])
    create index(:invoices, [:status])
    create unique_index(:invoices, [:business_id, :invoice_number])

    create table(:invoice_line_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all), null: false

      add :description, :string, null: false
      add :quantity, :integer, null: false
      add :unit_price, :decimal, null: false
      add :amount, :decimal, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:invoice_line_items, [:invoice_id])
  end
end
