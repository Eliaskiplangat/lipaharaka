defmodule Lipaharaka.Payments do
  @moduledoc """
  The Payments context: requesting M-Pesa STK Push payments for sent
  invoices, and processing Safaricom's callback when the buyer
  completes (or cancels) the prompt on their phone.

  As with Invoicing/Businesses, `request_payment/2` scopes to a given
  business — there is no way to request payment against an invoice
  you don't own. `handle_callback/1` is the one function in this
  module NOT scoped to a business, by necessity: Safaricom's callback
  identifies a payment only by `CheckoutRequestID`, which is how we
  look up which business/invoice it belongs to in the first place.

  ## Idempotency

  `handle_callback/1` always returns `:ok` at the top level (see
  `LipaharakaWeb.MpesaCallbackController`), even when the referenced
  invoice can no longer be marked paid (e.g. it was already marked
  paid manually, or cancelled, between the STK Push and the callback
  arriving). `Lipaharaka.Invoicing.mark_paid/2` returning
  `{:error, :invalid_transition}` in that situation is expected, not
  an error to surface — we still record the payment's own success/
  failure status either way.
  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Businesses.Business
  alias Lipaharaka.Invoicing
  alias Lipaharaka.Invoicing.Invoice
  alias Lipaharaka.Payments.Payment

  @doc """
  Initiates an M-Pesa STK Push for a `"sent"` invoice, prompting the
  buyer's phone for payment. Creates a `Payment` row in `"pending"`
  status, to be updated once `handle_callback/1` processes Safaricom's
  response (which may arrive seconds or, in edge cases, much longer
  later).
  """
  @spec request_payment(Business.t(), String.t()) ::
          {:ok, Payment.t()}
          | {:error, :not_found | :invalid_invoice_status | {:mpesa_request_failed, term()} | Ecto.Changeset.t()}
  def request_payment(%Business{} = business, invoice_id) do
    case Invoicing.get_invoice_for_business(business, invoice_id) do
      nil -> {:error, :not_found}
      %Invoice{status: "sent"} = invoice -> do_request_payment(invoice)
      %Invoice{} -> {:error, :invalid_invoice_status}
    end
  end

  defp do_request_payment(%Invoice{} = invoice) do
    description = "Invoice " <> invoice.invoice_number

    case Lipaharaka.Mpesa.stk_push(invoice.buyer_phone, invoice.total, invoice.invoice_number, description) do
      {:ok, %{checkout_request_id: checkout_id, merchant_request_id: merchant_id}} ->
        %Payment{}
        |> Payment.create_changeset(%{
          invoice_id: invoice.id,
          checkout_request_id: checkout_id,
          merchant_request_id: merchant_id,
          phone_number: invoice.buyer_phone,
          amount: invoice.total
        })
        |> Repo.insert()

      {:error, reason} ->
        {:error, {:mpesa_request_failed, reason}}
    end
  end

  @doc """
  Processes a Daraja STK callback payload. Looks up the matching
  `Payment` by `CheckoutRequestID`; if found, updates it to
  `"success"` or `"failed"` based on `ResultCode`, and on success,
  marks the associated invoice paid.

  Returns `{:error, :unmatched_callback}` if no payment matches the
  given checkout ID — the controller still acknowledges Safaricom
  with a 200 either way (see its moduledoc for why).
  """
  @spec handle_callback(map()) :: {:ok, Payment.t()} | {:error, :unmatched_callback | :invalid_callback}
  def handle_callback(%{"Body" => %{"stkCallback" => callback}}) when is_map(callback) do
    case callback["CheckoutRequestID"] do
      checkout_id when is_binary(checkout_id) ->
        case get_payment_by_checkout_id(checkout_id) do
          nil -> {:error, :unmatched_callback}
          payment -> process_callback(payment, callback)
        end

      _ ->
        {:error, :invalid_callback}
    end
  end

  def handle_callback(_params), do: {:error, :invalid_callback}

  defp get_payment_by_checkout_id(checkout_id) do
    Payment
    |> Repo.get_by(checkout_request_id: checkout_id)
    |> case do
      nil -> nil
      payment -> Repo.preload(payment, invoice: :business)
    end
  end

  defp process_callback(%Payment{} = payment, %{"ResultCode" => 0} = callback) do
    metadata = extract_metadata(callback)

    result =
      payment
      |> Payment.success_changeset(%{
        mpesa_receipt_number: metadata["MpesaReceiptNumber"],
        result_code: 0,
        result_desc: callback["ResultDesc"],
        raw_callback: callback
      })
      |> Repo.update()

    with {:ok, updated_payment} <- result do
      # Idempotent by design — see moduledoc. An invoice that's
      # already paid/cancelled by the time this callback arrives is
      # an expected race, not an error.
      _ = Invoicing.mark_paid(payment.invoice.business, payment.invoice_id)
      {:ok, updated_payment}
    end
  end

  defp process_callback(%Payment{} = payment, callback) do
    payment
    |> Payment.failed_changeset(%{
      result_code: callback["ResultCode"],
      result_desc: callback["ResultDesc"],
      raw_callback: callback
    })
    |> Repo.update()
  end

  defp extract_metadata(%{"CallbackMetadata" => %{"Item" => items}}) do
    Enum.reduce(items, %{}, fn %{"Name" => name, "Value" => value}, acc -> Map.put(acc, name, value) end)
  end

  defp extract_metadata(_), do: %{}
end
