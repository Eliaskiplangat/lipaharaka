defmodule Lipaharaka.Businesses.KycDocument do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @document_types ~w(national_id certificate_of_registration kra_pin_certificate mpesa_statement)
  @allowed_content_types ~w(image/jpeg image/png application/pdf)
  @max_file_size_bytes 5 * 1024 * 1024

  schema "kyc_documents" do
    field :document_type, :string
    field :storage_key, :string
    field :original_filename, :string
    field :content_type, :string
    field :file_size_bytes, :integer
    field :status, :string, default: "pending"
    field :review_note, :string
    field :reviewed_at, :utc_datetime

    belongs_to :business, Lipaharaka.Businesses.Business

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          business_id: Ecto.UUID.t() | nil,
          document_type: String.t() | nil,
          storage_key: String.t() | nil,
          original_filename: String.t() | nil,
          content_type: String.t() | nil,
          file_size_bytes: integer() | nil,
          status: String.t(),
          review_note: String.t() | nil,
          reviewed_at: DateTime.t() | nil
        }

  def document_types, do: @document_types
  def allowed_content_types, do: @allowed_content_types
  def max_file_size_bytes, do: @max_file_size_bytes

  @doc """
  Changeset for creating a KYC document record. `business_id` and
  `storage_key` are set by the context after the file has already
  been successfully written to storage — see
  `Lipaharaka.Businesses.upload_kyc_document/3`.
  """
  def create_changeset(document, attrs) do
    document
    |> cast(attrs, [
      :business_id,
      :document_type,
      :storage_key,
      :original_filename,
      :content_type,
      :file_size_bytes
    ])
    |> validate_required([
      :business_id,
      :document_type,
      :storage_key,
      :original_filename,
      :content_type,
      :file_size_bytes
    ])
    |> validate_inclusion(:document_type, @document_types)
    |> validate_inclusion(:content_type, @allowed_content_types)
    |> validate_number(:file_size_bytes, greater_than: 0, less_than_or_equal_to: @max_file_size_bytes)
    |> foreign_key_constraint(:business_id)
    |> unique_constraint([:business_id, :document_type],
      message: "already uploaded — delete the existing one first to replace it"
    )
  end
end
