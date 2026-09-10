defmodule Lipaharaka.Mpesa.Daraja do
  @moduledoc """
  Real M-Pesa integration via Safaricom's Daraja API (STK Push /
  Lipa Na M-Pesa Online).

  Required config:

      config :lipaharaka, :mpesa_adapter, Lipaharaka.Mpesa.Daraja

      config :lipaharaka, :mpesa,
        consumer_key: "...",
        consumer_secret: "...",
        shortcode: "...",           # your Paybill/Till number
        passkey: "...",             # Lipa Na M-Pesa Online passkey
        callback_url: "https://your-public-host/api/mpesa/callback",
        base_url: "https://sandbox.safaricom.co.ke"  # or https://api.safaricom.co.ke for live

  `callback_url` MUST be publicly reachable over HTTPS — Safaricom
  needs to be able to POST to it. For local development this
  typically means a tunnel (e.g. ngrok) pointed at your dev server;
  `localhost` will not work.
  """

  @behaviour Lipaharaka.Mpesa

  alias Lipaharaka.Mpesa.TokenCache

  @impl true
  def stk_push(phone_number, amount, account_reference, description) do
    config = Application.fetch_env!(:lipaharaka, :mpesa)
    base_url = config[:base_url] || "https://sandbox.safaricom.co.ke"

    with {:ok, token} <- TokenCache.get_token(fn -> fetch_access_token(config, base_url) end) do
      shortcode = Keyword.fetch!(config, :shortcode)
      passkey = Keyword.fetch!(config, :passkey)
      timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
      password = Base.encode64(shortcode <> passkey <> timestamp)

      body = %{
        "BusinessShortCode" => shortcode,
        "Password" => password,
        "Timestamp" => timestamp,
        "TransactionType" => "CustomerPayBillOnline",
        "Amount" => amount |> Decimal.round(0) |> Decimal.to_integer(),
        "PartyA" => phone_number,
        "PartyB" => shortcode,
        "PhoneNumber" => phone_number,
        "CallBackURL" => Keyword.fetch!(config, :callback_url),
        "AccountReference" => account_reference,
        "TransactionDesc" => description
      }

      request = Req.new(base_url: base_url, headers: [{"authorization", "Bearer " <> token}])

      case Req.post(request, url: "/mpesa/stkpush/v1/processrequest", json: body) do
        {:ok, %{status: 200, body: %{"CheckoutRequestID" => checkout_id, "MerchantRequestID" => merchant_id}}} ->
          {:ok, %{checkout_request_id: checkout_id, merchant_request_id: merchant_id}}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, {:unexpected_status, status, resp_body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_access_token(config, base_url) do
    consumer_key = Keyword.fetch!(config, :consumer_key)
    consumer_secret = Keyword.fetch!(config, :consumer_secret)
    credentials = Base.encode64("#{consumer_key}:#{consumer_secret}")

    request = Req.new(base_url: base_url, headers: [{"authorization", "Basic " <> credentials}])

    case Req.get(request, url: "/oauth/v1/generate?grant_type=client_credentials") do
      {:ok, %{status: 200, body: %{"access_token" => token} = resp_body}} ->
        ttl = resp_body |> Map.get("expires_in", "3599") |> to_string() |> String.to_integer()
        {:ok, token, ttl}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:unexpected_status, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
