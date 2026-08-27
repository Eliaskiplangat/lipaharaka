defmodule LipaharakaWeb.InvoiceJSON do
  alias Lipaharaka.Invoicing
  alias Lipaharaka.Invoicing.{Invoice, LineItem}

  def index(%{invoices: invoices}) do
    %{invoices: Enum.map(invoices, &invoice_summary/1)}
  end

  def show(%{invoice: invoice}) do
    %{invoice: invoice_summary(invoice)}
  end

  def changeset_error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  # Monetary fields are always rendered as strings (e.g. "1500.00"),
  # never as bare JSON numbers. This sidesteps a real gotcha: whether
  # Decimal has a working Jason.Encoder depends on compile order
  # between the `decimal` and `jason` libraries, which isn't something
  # worth relying on. Returning money as strings is also simply the
  # safer contract for API consumers — it avoids any float rounding
  # ambiguity on their end too.
  defp invoice_summary(%Invoice{} = invoice) do
    %{
      id: invoice.id,
      invoice_number: invoice.invoice_number,
      buyer_name: invoice.buyer_name,
      buyer_phone: invoice.buyer_phone,
      buyer_email: invoice.buyer_email,
      issue_date: invoice.issue_date,
      due_date: invoice.due_date,
      status: invoice.status,
      is_overdue: Invoicing.overdue?(invoice),
      subtotal: to_money_string(invoice.subtotal),
      tax_rate: to_money_string(invoice.tax_rate),
      tax_amount: to_money_string(invoice.tax_amount),
      total: to_money_string(invoice.total),
      notes: invoice.notes,
      sent_at: invoice.sent_at,
      paid_at: invoice.paid_at,
      cancelled_at: invoice.cancelled_at,
      line_items: Enum.map(invoice.line_items, &line_item_summary/1)
    }
  end

  defp line_item_summary(%LineItem{} = item) do
    %{
      id: item.id,
      description: item.description,
      quantity: item.quantity,
      unit_price: to_money_string(item.unit_price),
      amount: to_money_string(item.amount)
    }
  end

  defp to_money_string(nil), do: nil
  defp to_money_string(%Decimal{} = d), do: Decimal.to_string(d, :normal)

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
