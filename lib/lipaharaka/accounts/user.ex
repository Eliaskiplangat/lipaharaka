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

    # sme | admin. Deliberately NOT castable from client params in
    # registration_changeset — there is no request field anywhere
    # that lets a client set this. Promotion to admin happens outside
    # the API entirely (iex/direct DB update) for now — see README
    # Step 6 for why.
    field :role, :string, default: "sme"

    # OTP fields are intentionally minimal: we store only a hash of the
    # OTP (never the plaintext code) plus an expiry and an attempt
    # counter used to rate-limit brute-force guesses.
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
          role: String.t(),
          otp_hash: String.t() | nil,
          otp_expires_at: DateTime.t() | nil,
          otp_attempts: integer()
        }

  @doc """
  Changeset for registering a new user: validates and normalizes the
  phone number, validates the password, and hashes it. Does NOT touch
  OTP fields — that's a separate step via `otp_changeset/2`. Note
  `:role` is not in the cast list, on purpose — see the schema comment.
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
  Changeset used when generating a fresh OTP for a user (at registration
  time, or when re-requesting a code). Stores only the hash + expiry.
  """
  def otp_changeset(user, otp_hash, expires_at) do
    change(user, otp_hash: otp_hash, otp_expires_at: expires_at, otp_attempts: 0)
  end

  @doc """
  Changeset applied once an OTP has been successfully verified: marks
  the phone as verified and clears the OTP fields so the code can't be
  reused.
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

  @doc false
  def role_changeset(user, role) when role in ~w(sme admin) do
    change(user, role: role)
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
