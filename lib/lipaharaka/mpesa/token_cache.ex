defmodule Lipaharaka.Mpesa.TokenCache do
  @moduledoc """
  Caches the Daraja OAuth access token in memory so
  `Lipaharaka.Mpesa.Daraja` doesn't request a fresh token on every
  single STK Push (Safaricom's tokens are valid for ~1 hour).

  Same lazy-start pattern as `Lipaharaka.SMS.Test` — no supervision
  tree change needed, the Agent starts itself on first use.
  """

  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> nil end, name: __MODULE__)

  @doc """
  Returns a cached, still-valid token if one exists; otherwise calls
  `fetch_fun` (expected to return `{:ok, token, ttl_seconds}` or
  `{:error, reason}`) and caches the result, expiring it slightly
  before Safaricom says it actually will, as a safety margin against
  clock drift and in-flight requests.
  """
  @spec get_token((-> {:ok, String.t(), integer()} | {:error, term()})) ::
          {:ok, String.t()} | {:error, term()}
  def get_token(fetch_fun) do
    ensure_started()

    case Agent.get(__MODULE__, & &1) do
      {token, expires_at} ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, token}
        else
          fetch_and_cache(fetch_fun)
        end

      nil ->
        fetch_and_cache(fetch_fun)
    end
  end

  defp fetch_and_cache(fetch_fun) do
    case fetch_fun.() do
      {:ok, token, ttl_seconds} ->
        margin = min(60, max(ttl_seconds - 1, 0))
        expires_at = DateTime.utc_now() |> DateTime.add(ttl_seconds - margin, :second)
        Agent.update(__MODULE__, fn _ -> {token, expires_at} end)
        {:ok, token}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_link([])
      _pid -> :ok
    end
  end
end
