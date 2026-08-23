defmodule Lipaharaka.Businesses.Business do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @kyc_statuses ~w(pending approved rejected)

  schema "businesses" do
    field :business_name, :string
    field :registration_number, :string
    field :kra_pin, :string
    field :sector, :string
    field :mpesa_till_or_paybill, :string
    field :kyc_status, :string, default: "pending"

    belongs_to :user, Lipaharaka.Accounts.User
    has_many :kyc_documents, Lipaharaka.Businesses.KycDocument

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          business_name: String.t() | nil,
          registration_number: String.t() | nil,
          kra_pin: String.t() | nil,
          sector: String.t() | nil,
          mpesa_till_or_paybill: String.t() | nil,
          kyc_status: String.t()
        }

  @doc """
  Changeset for creating a business. `user_id` is set separately by
  the context (from `conn.assigns.current_user`, never from client
  params) — see `Lipaharaka.Businesses.create_business/2`.
  """
  def create_changeset(business, attrs) do
    business
    |> cast(attrs, [:business_name, :registration_number, :kra_pin, :sector, :mpesa_till_or_paybill])
    |> validate_required([:business_name])
    |> validate_length(:business_name, min: 2, max: 160)
    |> validate_kra_pin()
    |> unique_constraint(:user_id, message: "you already have a registered business")
  end

  @doc """
  Changeset for updating an existing business's profile fields. Does
  NOT allow changing `kyc_status` — that's a separate, Admin-only
  action (`Lipaharaka.Businesses.review_kyc/2`, added alongside the
  Admin review flow).
  """
  def update_changeset(business, attrs) do
    business
    |> cast(attrs, [:business_name, :registration_number, :kra_pin, :sector, :mpesa_till_or_paybill])
    |> validate_length(:business_name, min: 2, max: 160)
    |> validate_kra_pin()
  end

  @doc false
  def kyc_status_changeset(business, status) when status in @kyc_statuses do
    change(business, kyc_status: status)
  end

  defp validate_kra_pin(changeset) do
    validate_format(changeset, :kra_pin, ~r/^[A-Z]\d{9}[A-Z]$/,
      message: "must be a valid KRA PIN format, e.g. A123456789Z"
    )
  end
end
