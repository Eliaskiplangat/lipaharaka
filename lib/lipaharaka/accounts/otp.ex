defmodule Lipaharaka.Accounts.Otp do
  @moduledoc """

  """
  @otp_length 6
  @otp_validity_minutes 5
  @max_attempts 5


  @spec generate_code() :: String.t()
  def generate_code do
    @otp_length
    |> :crypto.strong_rand_bytes()
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> Integer.to_string(rem(byte, 10)) end)
    |> Enum.join()
  end


  @spec hash(String.t()) :: String.t()
  def hash(code) do
    :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)
  end

  @spec expires_at() :: DateTime.t()
  def expires_at do
    DateTime.utc_now() |> DateTime.add(@otp_validity_minutes * 60, :second) |> DateTime.truncate(:second)
  end

  @spec verify(Lipaharaka.Accounts.User.t(), String.t()) ::
          :ok | {:error, :no_otp_pending | :expired | :too_many_attempts | :incorrect}
  def verify(user, submitted_code) do
    cond do
      is_nil(user.otp_hash) or is_nil(user.otp_expires_at) ->
        {:error, :no_otp_pending}

      user.otp_attempts >= @max_attempts ->
        {:error, :too_many_attempts}

      DateTime.compare(DateTime.utc_now(), user.otp_expires_at) == :gt ->
        {:error, :expired}

      Plug.Crypto.secure_compare(hash(submitted_code), user.otp_hash) ->
        :ok

      true ->
        {:error, :incorrect}
    end
  end

  def max_attempts, do: @max_attempts
  def validity_minutes, do: @otp_validity_minutes
end
