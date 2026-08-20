defmodule Lipaharaka.Accounts.PhoneNumber do
  @moduledoc """

  """
  @spec normalize(String.t()) :: {:ok, String.t()} | :error
  def normalize(phone) when is_binary(phone) do
    digits = phone |> String.trim() |> String.replace(~r/[^0-9+]/, "")

    normalized =
      cond do
        String.match?(digits, ~r/^\+254[17]\d{8}$/) -> digits
        String.match?(digits, ~r/^254[17]\d{8}$/) -> "+" <> digits
        String.match?(digits, ~r/^0[17]\d{8}$/) -> "+254" <> String.slice(digits, 1..-1//1)
        true -> nil
      end

    if normalized, do: {:ok, normalized}, else: :error
  end

  def normalize(_), do: :error
end
