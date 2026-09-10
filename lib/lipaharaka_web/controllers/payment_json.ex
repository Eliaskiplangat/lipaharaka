defmodule LipaharakaWeb.PaymentJSON do
  alias Lipaharaka.Payments.Payment

  def show(%{payment: payment}) do
    %{
      payment: payment_summary(payment),
      message: "Payment request sent. Check your phone to complete the M-Pesa payment."
    }
  end

  def changeset_error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  # Deliberately omits raw_callback — internal debugging detail, not
  # something an API consumer needs or should see.
  defp payment_summary(%Payment{} = payment) do
    %{
      id: payment.id,
      status: payment.status,
      amount: Decimal.to_string(payment.amount, :normal),
      phone_number: payment.phone_number,
      checkout_request_id: payment.checkout_request_id,
      mpesa_receipt_number: payment.mpesa_receipt_number
    }
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
