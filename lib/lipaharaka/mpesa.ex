defmodule Lipaharaka.Mpesa do
  @moduledoc """
  Thin dispatcher over a configurable M-Pesa adapter, so the rest of
  the application never talks to Safaricom's Daraja API directly.

  Two adapters:

    * `Lipaharaka.Mpesa.Daraja` — the real integration (OAuth token
      caching + STK Push).
    * `Lipaharaka.Mpesa.Test` — **default in dev and test**. Unlike
      the SMS/Storage adapters, there is no meaningful "log to
      console" equivalent for M-Pesa — an STK Push fundamentally
      requires a real phone to confirm a real prompt. `Test` instead
      records each request in memory (so tests/dev exploration can
      inspect what would have been sent) and returns a canned
      success response with a fake checkout ID, without needing
      Safaricom sandbox credentials just to keep developing the rest
      of the payment flow (the request/response shape, the callback
      handling logic, etc.).

  Switch to `Daraja` in `config/dev.exs` once you have Safaricom
  sandbox credentials and want to test a real STK Push end to end
  (see README — this also requires a publicly reachable callback URL,
  e.g. via ngrok, since Safaricom must be able to POST back to it).
  """

  @type phone_number :: String.t()
  @type stk_result :: %{checkout_request_id: String.t(), merchant_request_id: String.t()}

  @callback stk_push(phone_number(), Decimal.t(), String.t(), String.t()) ::
              {:ok, stk_result()} | {:error, term()}

  @spec stk_push(phone_number(), Decimal.t(), String.t(), String.t()) ::
          {:ok, stk_result()} | {:error, term()}
  def stk_push(phone_number, amount, account_reference, description) do
    adapter().stk_push(phone_number, amount, account_reference, description)
  end

  defp adapter do
    Application.get_env(:lipaharaka, :mpesa_adapter, Lipaharaka.Mpesa.Test)
  end
end
