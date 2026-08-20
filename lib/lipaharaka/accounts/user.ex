defmodule Lipaharaka.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :phone_number, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :phone_verified_at, :utc_datetime


    field :otp_hash, :string, redact: true
    field :otp_expires_at, :utc_datetime
    field :otp_attempts, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          phone_number: String.t() | nil,
          password: String.t() | nil,
          password_hash: String.t() | nil,
          phone_verified_at: DateTime.t() | nil,
          otp_hash: String.t() | nil,
          otp_expires_at: DateTime.t() | nil,
          otp_attempts: integer()
        }

  @doc """

  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone_number, :password])
    |> validate_required([:phone_number, :password])
    |> validate_and_normalize_phone()
    |> validate_length(:password, min: 8, max: 72)
    |> unique_constraint(:phone_number)
    |> put_password_hash()
  end

  @doc """

  """
  def otp_changeset(user, otp_hash, expires_at) do
    change(user, otp_hash: otp_hash, otp_expires_at: expires_at, otp_attempts: 0)
  end

  @doc """

  """
  def verified_changeset(user) do
    change(user,
      phone_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
      otp_hash: nil,
      otp_expires_at: nil,
      otp_attempts: 0
    )
  end

  @doc "Increments the failed OTP attempt counter (used for rate limiting)."
  def increment_otp_attempts(user) do
    change(user, otp_attempts: user.otp_attempts + 1)
  end

  defp validate_and_normalize_phone(changeset) do
    case get_change(changeset, :phone_number) do
      nil ->
        changeset

      phone ->
        case Lipaharaka.Accounts.PhoneNumber.normalize(phone) do
          {:ok, normalized} -> put_change(changeset, :phone_number, normalized)
          :error -> add_error(changeset, :phone_number, "is not a valid Kenyan phone number")
        end
    end
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
