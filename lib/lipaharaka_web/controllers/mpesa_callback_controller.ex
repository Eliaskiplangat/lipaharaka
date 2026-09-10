defmodule LipaharakaWeb.MpesaCallbackController do
  use LipaharakaWeb, :controller

  @moduledoc """
  Public endpoint that Safaricom's Daraja API calls with STK Push
  results. Deliberately unauthenticated — Safaricom cannot present
  our bearer tokens, and Daraja does not offer request signing for
  callbacks. In production this endpoint should additionally be
  protected by IP allowlisting at the infrastructure/load-balancer
  level (Safaricom publishes their callback source IP ranges) — that
  protection lives outside what this controller itself can enforce.

  Always acknowledges receipt with HTTP 200 and the exact JSON shape
  Daraja expects, REGARDLESS of whether we could match the callback
  to a known payment. Safaricom retries aggressively on any non-200
  response, and a genuinely unmatched `CheckoutRequestID` will never
  resolve itself through retries — acknowledging and moving on avoids
  a retry storm without changing the outcome.
  """

  require Logger

  def create(conn, params) do
    case Lipaharaka.Payments.handle_callback(params) do
      {:ok, _payment} ->
        :ok

      {:error, :unmatched_callback} ->
        Logger.warning("M-Pesa callback received for unknown CheckoutRequestID: #{inspect(params)}")

      {:error, :invalid_callback} ->
        Logger.warning("M-Pesa callback received with unexpected shape: #{inspect(params)}")
    end

    json(conn, %{"ResultCode" => 0, "ResultDesc" => "Accepted"})
  end
end
