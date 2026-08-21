defmodule LipaharakaWeb.Auth.Token do

  @salt "user auth"
  @max_age_seconds 60 * 60 * 24 * 30
  @spec sign(Ecto.UUID.t(), keyword()) :: String.t()
  def sign(user_id, opts \\ []) do
    Phoenix.Token.sign(LipaharakaWeb.Endpoint, @salt, user_id, opts)
  end
  @spec verify(String.t()) :: {:ok, Ecto.UUID.t()} | {:error, :invalid | :expired | :missing}
  def verify(nil), do: {:error, :missing}

  def verify(token) do
    case Phoenix.Token.verify(LipaharakaWeb.Endpoint, @salt, token, max_age: @max_age_seconds) do
      {:ok, user_id} -> {:ok, user_id}
      {:error, :expired} -> {:error, :expired}
      {:error, _reason} -> {:error, :invalid}
    end
  end
end
