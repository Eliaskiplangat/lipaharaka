defmodule Lipaharaka.Repo.Migrations.CreateMpesaPayments do
  use Ecto.Migration

  def change do
    create table(:mpesa_payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all), null: false

      add :checkout_request_id, :string, null: false
      add :merchant_request_id, :string
      add :phone_number, :string, null: false
      add :amount, :decimal, null: false

      # pending | success | failed
      add :status, :string, null: false, default: "pending"

      add :mpesa_receipt_number, :string
      add :result_code, :integer
      add :result_desc, :string

      # Full raw callback payload, kept for debugging/audit — Daraja's
      # callback shape has surprised integrators before (e.g. metadata
      # item ordering, occasional missing fields on edge cases), so
      # having the original JSON on hand matters more here than for
      # most other integrations.
      add :raw_callback, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mpesa_payments, [:checkout_request_id])
    create index(:mpesa_payments, [:invoice_id])
  end
end
