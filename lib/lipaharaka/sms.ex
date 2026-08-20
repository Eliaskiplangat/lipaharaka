defmodule Lipaharaka.SMS do
  @moduledoc """
  Thin dispatcher over a configurable SMS adapter, so the rest of the
  application never talks to Africa's Talking (or any SMS provider)
  directly — it just calls `Lipaharaka.SMS.send/2`.

  The adapter is chosen via config:

      config :lipaharaka, :sms_adapter, Lipaharaka.SMS.AfricasTalking

  Three adapters exist:

    * `Lipaharaka.SMS.AfricasTalking` — the real integration, used in
      production (and optionally in dev/test if you have sandbox
      credentials and want to test against the real API).
    * `Lipaharaka.SMS.Console` — logs the message instead of sending it.
      This is the default in `dev`, so you can develop and test the OTP
      flow end-to-end without needing an Africa's Talking account yet.
    * `Lipaharaka.SMS.Test` — collects sent messages in memory so tests
      can assert on what was "sent". Default in `test`.
  """

  @type phone_number :: String.t()
  @type message :: String.t()

  @callback send(phone_number(), message()) :: {:ok, map()} | {:error, term()}

  @spec send(phone_number(), message()) :: {:ok, map()} | {:error, term()}
  def send(phone_number, message) do
    adapter().send(phone_number, message)
  end

  defp adapter do
    Application.get_env(:lipaharaka, :sms_adapter, Lipaharaka.SMS.Console)
  end
end
