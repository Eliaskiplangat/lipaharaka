defmodule Lipaharaka.Accounts do
  @moduledoc """
  The Accounts context: user registration, phone verification via OTP,
  and login.

  This is intentionally the *only* module outside of `Lipaharaka.Accounts.*`
  that should query the `users` table directly. Controllers and other
  contexts call into here, not into `Lipaharaka.Accounts.User`/`Repo`
  directly — that boundary is what makes it possible to later change
  how, say, OTPs are generated without touching the web layer at all.
  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Accounts.{User, OTP}

  @doc """
  Registers a new user and sends them an OTP via SMS to verify their
  phone number.

  Returns `{:ok, user}` on success (the user's `phone_verified_at` will
  be `nil` until they verify), or `{:error, changeset}` on validation
  failure (e.g. duplicate phone number, weak password).

  Note: if the user record is created successfully but the SMS fails to
  send, we still return `{:ok, user}` — the user can request a fresh
  OTP via `resend_otp/1`. We don't want a flaky SMS provider to make
  registration itself fail.
  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    with {:ok, user} <-
           %User{}
           |> User.registration_changeset(attrs)
           |> Repo.insert() do
      {:ok, user} = issue_and_send_otp(user)
      {:ok, user}
    end
  end

  @doc """
  Generates a fresh OTP for a user and sends it via SMS. Used both
  right after registration and when a user asks for the code to be
  resent.
  """
  @spec issue_and_send_otp(User.t()) :: {:ok, User.t()} | {:error, term()}
  def issue_and_send_otp(%User{} = user) do
    code = OTP.generate_code()

    {:ok, user} =
      user
      |> User.otp_changeset(OTP.hash(code), OTP.expires_at())
      |> Repo.update()

    message =
      "Your LipaHaraka verification code is #{code}. It expires in #{OTP.validity_minutes()} minutes."

    case Lipaharaka.SMS.send(user.phone_number, message) do
      {:ok, _} -> {:ok, user}
      # We still return {:ok, user} here — the OTP was generated and
      # stored, so the user can retry verification once the SMS issue
      # is resolved, or call resend_otp/1 again.
      {:error, _reason} -> {:ok, user}
    end
  end

  @doc """
  Verifies a submitted OTP code for the user with the given phone
  number.

  Returns `{:ok, user}` with `phone_verified_at` now set, or
  `{:error, reason}` where reason is `:not_found` or one of the reasons
  from `Lipaharaka.Accounts.OTP.verify/2`.
  """
  @spec verify_otp(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :not_found | atom()}
  def verify_otp(phone_number, submitted_code) do
    with {:ok, normalized} <- Lipaharaka.Accounts.PhoneNumber.normalize(phone_number),
         %User{} = user <- get_user_by_phone(normalized) do
      case OTP.verify(user, submitted_code) do
        :ok ->
          user |> User.verified_changeset() |> Repo.update()

        {:error, reason} ->
          # Record the failed attempt so repeated guessing gets locked out.
          user |> User.increment_otp_attempts() |> Repo.update()
          {:error, reason}
      end
    else
      :error -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Authenticates a user by phone number and password. Requires the
  phone to already be verified.

  Returns `{:ok, user}`, `{:error, :invalid_credentials}`, or
  `{:error, :phone_not_verified}`.
  """
  @spec authenticate(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_credentials | :phone_not_verified}
  def authenticate(phone_number, password) do
    with {:ok, normalized} <- Lipaharaka.Accounts.PhoneNumber.normalize(phone_number),
         %User{} = user <- get_user_by_phone(normalized),
         true <- Bcrypt.verify_pass(password, user.password_hash) do
      if user.phone_verified_at do
        {:ok, user}
      else
        {:error, :phone_not_verified}
      end
    else
      _ ->
        # Run a dummy hash even when the user doesn't exist, so
        # responses take a similar amount of time either way and don't
        # leak which phone numbers are registered via timing.
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc "Fetches a user by (already-normalized) phone number, or nil."
  @spec get_user_by_phone(String.t()) :: User.t() | nil
  def get_user_by_phone(phone_number) do
    Repo.get_by(User, phone_number: phone_number)
  end

  @doc "Fetches a user by ID, or nil."
  @spec get_user(Ecto.UUID.t()) :: User.t() | nil
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Promotes a user to the `admin` role. Deliberately not exposed via
  any API endpoint — there is no self-service or even
  authenticated-user path to becoming an admin. Call this from `iex`
  (`Lipaharaka.Accounts.promote_to_admin(user)`) when you need an
  admin account for testing or genuine operational use. If this ever
  needs to be exposed over HTTP, that should be a deliberately
  separate, heavily-guarded "super-admin" action — not a reuse of any
  existing user-facing endpoint.
  """
  @spec promote_to_admin(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def promote_to_admin(%User{} = user) do
    user
    |> User.role_changeset("admin")
    |> Repo.update()
  end
end
