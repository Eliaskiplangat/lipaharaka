defmodule LipaharakaWeb.AuthJSON do
  alias Lipaharaka.Accounts.User


  def registered(%{user: user}) do
    %{
      user: user_summary(user),
      message: "Registered. A verification code has been sent via SMS."
    }
  end


  def verified(%{user: user, token: token}) do
    %{
      user: user_summary(user),
      token: token,
      message: "Phone number verified."
    }
  end


  def logged_in(%{user: user, token: token}) do
    %{
      user: user_summary(user),
      token: token,
      message: "Login successful."
    }
  end

  def me(%{user: user}) do
    %{user: user_summary(user)}
  end


  def changeset_error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end


  def otp_error(%{reason: reason}) do
    %{errors: %{otp: otp_error_message(reason)}}
  end

  defp otp_error_message(:no_otp_pending), do: "no verification code is pending for this number"
  defp otp_error_message(:expired), do: "code has expired, please request a new one"
  defp otp_error_message(:too_many_attempts), do: "too many incorrect attempts, please request a new code"
  defp otp_error_message(:incorrect), do: "incorrect code"
  defp otp_error_message(:not_found), do: "phone number not found"
  defp otp_error_message(_), do: "verification failed"

  defp user_summary(%User{} = user) do
    %{
      id: user.id,
      phone_number: user.phone_number,
      phone_verified: not is_nil(user.phone_verified_at)
    }
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
