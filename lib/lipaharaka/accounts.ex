defmodule Lipaharaka.Accounts do
  @moduledoc """

  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Accounts.{User, OTP}
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

      {:error, _reason} -> {:ok, user}
    end
  end


  @spec verify_otp(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :not_found | atom()}
  def verify_otp(phone_number, submitted_code) do
    with {:ok, normalized} <- Lipaharaka.Accounts.PhoneNumber.normalize(phone_number),
         %User{} = user <- get_user_by_phone(normalized) do
      case OTP.verify(user, submitted_code) do
        :ok ->
          user |> User.verified_changeset() |> Repo.update()

        {:error, reason} ->
          user |> User.increment_otp_attempts() |> Repo.update()
          {:error, reason}
      end
    else
      :error -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

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
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @spec get_user_by_phone(String.t()) :: User.t() | nil
  def get_user_by_phone(phone_number) do
    Repo.get_by(User, phone_number: phone_number)
  end
  @spec get_user(Ecto.UUID.t()) :: User.t() | nil
  def get_user(id) do
    Repo.get(User, id)
  end
end
