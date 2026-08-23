defmodule Lipaharaka.Repo.Migrations.CreateKycDocuments do
  use Ecto.Migration

  def change do
    create table(:kyc_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :business_id, references(:businesses, type: :binary_id, on_delete: :delete_all),
        null: false

      # national_id | certificate_of_registration | kra_pin_certificate | mpesa_statement
      add :document_type, :string, null: false

      # Opaque storage key (S3 object key / local file path) — never
      # exposed directly to clients. Downloads go through a freshly
      # generated presigned URL instead (see Lipaharaka.Storage).
      add :storage_key, :string, null: false
      add :original_filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size_bytes, :integer, null: false

      # pending | approved | rejected — set by Admin review (FR-1.4),
      # not yet buildable (no Admin role exists), so this stays
      # "pending" for every document until that step.
      add :status, :string, null: false, default: "pending"
      add :review_note, :string
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:kyc_documents, [:business_id])

    # A business shouldn't be able to upload the same document type
    # twice (e.g. two "national_id" rows) — re-uploading should
    # replace, which the context handles by deleting the prior one
    # first rather than allowing duplicates to accumulate.
    create unique_index(:kyc_documents, [:business_id, :document_type])
  end
end
