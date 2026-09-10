defmodule Lipaharaka.Mpesa.Test do
  @moduledoc """
  Development/test M-Pesa adapter: records each STK Push request in
  memory and returns a canned success response, instead of calling
  Safaricom at all. Default in both `dev` and `test` — see
  `Lipaharaka.Mpesa` moduledoc for why there's no safer "real but
  local" equivalent for M-Pesa the way Console/Local work for
  SMS/Storage.

  Tests can use `last_request/0` to inspect what was "sent", and
  `simulate_callback/2` to build a realistic Daraja callback payload
  for testing `Lipaharaka.Payments.handle_callback/1` without needing
  Oban, a real webhook, or Safaricom at all.
  """

  @behaviour Lipaharaka.Mpesa

  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> [] end, name: __MODULE__)

  @impl true
  def stk_push(phone_number, amount, account_reference, description) do
    ensure_started()

    checkout_id = "test-checkout-#{System.unique_integer([:positive])}"
    merchant_id = "test-merchant-#{System.unique_integer([:positive])}"

    request = %{
      phone_number: phone_number,
      amount: amount,
      account_reference: account_reference,
      description: description,
      checkout_request_id: checkout_id,
      merchant_request_id: merchant_id
    }

    Agent.update(__MODULE__, fn requests -> [request | requests] end)

    {:ok, %{checkout_request_id: checkout_id, merchant_request_id: merchant_id}}
  end

  @doc "All STK Push requests made so far, most recent first."
  def requests do
    ensure_started()
    Agent.get(__MODULE__, & &1)
  end

  @doc "The most recently made STK Push request, or nil."
  def last_request do
    List.first(requests())
  end

  @doc "Clears all recorded requests."
  def clear do
    ensure_started()
    Agent.update(__MODULE__, fn _ -> [] end)
  end

  @doc """
  Builds a realistic Daraja STK callback payload for a given checkout
  request ID — `result_code: 0` for success (with a fake M-Pesa
  receipt number and the given amount), or any non-zero code plus
  `result_desc` for a failure/cancellation scenario.
  """
  def simulate_callback(checkout_request_id, opts \\ []) do
    result_code = Keyword.get(opts, :result_code, 0)
    amount = Keyword.get(opts, :amount, Decimal.new("1000.00"))
    phone_number = Keyword.get(opts, :phone_number, "254712345678")

    stk_callback =
      if result_code == 0 do
        %{
          "MerchantRequestID" => "test-merchant-callback",
          "CheckoutRequestID" => checkout_request_id,
          "ResultCode" => 0,
          "ResultDesc" => "The service request is processed successfully.",
          "CallbackMetadata" => %{
            "Item" => [
              %{"Name" => "Amount", "Value" => Decimal.to_float(amount)},
              %{"Name" => "MpesaReceiptNumber", "Value" => "TEST#{System.unique_integer([:positive])}"},
              %{"Name" => "TransactionDate", "Value" => 20_260_101_120_000},
              %{"Name" => "PhoneNumber", "Value" => String.to_integer(phone_number)}
            ]
          }
        }
      else
        %{
          "MerchantRequestID" => "test-merchant-callback",
          "CheckoutRequestID" => checkout_request_id,
          "ResultCode" => result_code,
          "ResultDesc" => Keyword.get(opts, :result_desc, "Request cancelled by user")
        }
      end

    %{"Body" => %{"stkCallback" => stk_callback}}
  end

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_link([])
      _pid -> :ok
    end
  end
end
