defmodule Lipaharaka.Invoicing do
  @moduledoc """
  The Invoicing context: invoice creation, updates, and status
  transitions (draft -> sent -> paid, or -> cancelled).

  As with Businesses, every function here scopes to a given
  `Lipaharaka.Businesses.Business` explicitly — there is no function
  that fetches "an invoice by id" alone. `get_invoice_for_business/2`
  returns `nil` for an invoice that exists but belongs to a different
  business, exactly as if it didn't exist at all, so a controller can
  never accidentally leak one SME's invoice to another.

  All monetary fields (`subtotal`, `tax_amount`, `total`, and each
  line item's `amount`) are computed here, server-side, from the
  submitted line items — never trusted directly from client input,
  even on update.

  A known limitation: `invoice_number` generation
  (`next_invoice_number/1`) counts existing invoices for the business
  and is NOT protected by a database-level lock or unique retry loop.
  Under genuinely concurrent invoice creation for the same business
  (two requests landing in the same moment), this could theoretically
  produce a duplicate number, which would then fail on the
  `unique_index(:invoices, [:business_id, :invoice_number])`
  constraint at the database level, insert fails and the second
  request's caller sees a validation error, not a silent invoice
  numbering collision. Acceptable for now given a single SME is very
  unlikely to submit two invoice-creation requests in the same
  instant; worth a proper fix (e.g. a Postgres sequence per business,
  or an advisory lock) if usage patterns ever suggest otherwise.
  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Businesses.Business
  alias Lipaharaka.Invoicing.Invoice

  @doc """
  Creates a draft invoice for the given business. `attrs` must include
  `"buyer_name"`, `"buyer_phone"`, `"issue_date"`, `"due_date"`, and
  `"line_items"` (a non-empty list of `%{"description", "quantity",
  "unit_price"}`); `"tax_rate"` and `"buyer_email"`/`"notes"` are
  optional.
  """
  @spec create_invoice(Business.t(), map()) ::
          {:ok, Invoice.t()} | {:error, :line_items_required | :invalid_line_item | Ecto.Changeset.t()}
  def create_invoice(%Business{} = business, attrs) do
    with {:ok, prepared_items} <- prepare_line_items(Map.get(attrs, "line_items")),
         {:ok, tax_rate} <- to_decimal(Map.get(attrs, "tax_rate", 0)) do
      subtotal = sum_amounts(prepared_items)
      tax_amount = subtotal |> Decimal.mult(tax_rate) |> Decimal.div(100)
      total = Decimal.add(subtotal, tax_amount)

      invoice_attrs =
        attrs
        |> Map.put("line_items", prepared_items)
        |> Map.put("subtotal", subtotal)
        |> Map.put("tax_rate", tax_rate)
        |> Map.put("tax_amount", tax_amount)
        |> Map.put("total", total)
        |> Map.put("business_id", business.id)
        |> Map.put("invoice_number", next_invoice_number(business))

      %Invoice{}
      |> Invoice.create_changeset(invoice_attrs)
      |> Repo.insert()
    end
  end

  @doc "Fetches an invoice belonging to the given business, preloaded with line items, or nil."
  @spec get_invoice_for_business(Business.t(), String.t()) :: Invoice.t() | nil
  def get_invoice_for_business(%Business{} = business, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Invoice
        |> Repo.get_by(id: uuid, business_id: business.id)
        |> case do
          nil -> nil
          invoice -> Repo.preload(invoice, :line_items)
        end

      :error ->
        nil
    end
  end

  @doc "Lists a business's invoices, most recently created first, each preloaded with line items."
  @spec list_invoices_for_business(Business.t()) :: [Invoice.t()]
  def list_invoices_for_business(%Business{} = business) do
    Repo.all(
      from i in Invoice,
        where: i.business_id == ^business.id,
        order_by: [desc: i.inserted_at],
        preload: :line_items
    )
  end

  @doc """
  Updates a draft invoice. If `attrs` includes `"line_items"`, they
  (and totals) are fully recomputed and replaced, same validation path
  as creation. Otherwise, only buyer/date/notes fields are updated.

  Returns `{:error, :not_found}` if the business has no such invoice,
  or `{:error, :not_editable}` if the invoice is no longer a draft
  (sent/paid/cancelled invoices cannot be edited — cancel and
  re-create instead).
  """
  @spec update_invoice(Business.t(), String.t(), map()) ::
          {:ok, Invoice.t()}
          | {:error, :not_found | :not_editable | :invalid_line_item | Ecto.Changeset.t()}
  def update_invoice(%Business{} = business, id, attrs) do
    case get_invoice_for_business(business, id) do
      nil -> {:error, :not_found}
      %Invoice{status: "draft"} = invoice -> do_update_invoice(invoice, attrs)
      %Invoice{} -> {:error, :not_editable}
    end
  end

  defp do_update_invoice(invoice, %{"line_items" => raw_items} = attrs) do
    with {:ok, prepared_items} <- prepare_line_items(raw_items),
         {:ok, tax_rate} <- to_decimal(Map.get(attrs, "tax_rate", invoice.tax_rate)) do
      subtotal = sum_amounts(prepared_items)
      tax_amount = subtotal |> Decimal.mult(tax_rate) |> Decimal.div(100)
      total = Decimal.add(subtotal, tax_amount)

      full_attrs =
        attrs
        |> Map.put("line_items", prepared_items)
        |> Map.put("subtotal", subtotal)
        |> Map.put("tax_rate", tax_rate)
        |> Map.put("tax_amount", tax_amount)
        |> Map.put("total", total)

      invoice
      |> Invoice.replace_changeset(full_attrs)
      |> Repo.update()
    end
  end

  defp do_update_invoice(invoice, attrs) do
    invoice
    |> Invoice.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Transitions a draft invoice to sent."
  @spec send_invoice(Business.t(), String.t()) ::
          {:ok, Invoice.t()} | {:error, :not_found | :invalid_transition}
  def send_invoice(%Business{} = business, id) do
    transition(business, id, from: "draft", to: "sent")
  end

  @doc """
  Marks a sent invoice as paid. This is a manual, Admin/SME-triggered
  action for now — automatic reconciliation against actual M-Pesa
  payment confirmations is a later step, not yet built.
  """
  @spec mark_paid(Business.t(), String.t()) ::
          {:ok, Invoice.t()} | {:error, :not_found | :invalid_transition}
  def mark_paid(%Business{} = business, id) do
    transition(business, id, from: "sent", to: "paid")
  end

  @doc "Cancels a draft or sent invoice."
  @spec cancel_invoice(Business.t(), String.t()) ::
          {:ok, Invoice.t()} | {:error, :not_found | :invalid_transition}
  def cancel_invoice(%Business{} = business, id) do
    case get_invoice_for_business(business, id) do
      nil ->
        {:error, :not_found}

      %Invoice{status: status} = invoice when status in ["draft", "sent"] ->
        invoice |> Invoice.status_changeset("cancelled") |> Repo.update()

      %Invoice{} ->
        {:error, :invalid_transition}
    end
  end

  defp transition(business, id, from: from_status, to: to_status) do
    case get_invoice_for_business(business, id) do
      nil -> {:error, :not_found}
      %Invoice{status: ^from_status} = invoice -> invoice |> Invoice.status_changeset(to_status) |> Repo.update()
      %Invoice{} -> {:error, :invalid_transition}
    end
  end

  @doc """
  Returns whether an invoice is currently overdue: still `sent`
  (not yet paid or cancelled) and past its due date. Computed at read
  time rather than stored, so no background job is needed to keep it
  accurate — see the moduledoc's scope note.
  """
  @spec overdue?(Invoice.t()) :: boolean()
  def overdue?(%Invoice{status: "sent", due_date: due_date}) do
    Date.compare(Date.utc_today(), due_date) == :gt
  end

  def overdue?(%Invoice{}), do: false

  # ============================================================
  # Line item preparation (server-side amount computation)
  # ============================================================

  defp prepare_line_items(items) when is_list(items) and items != [] do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case prepare_line_item(item) do
        {:ok, prepared} -> {:cont, {:ok, [prepared | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp prepare_line_items(_), do: {:error, :line_items_required}

  defp prepare_line_item(%{"description" => description} = item)
       when is_binary(description) and description != "" do
    with {:ok, quantity} <- to_integer(Map.get(item, "quantity")),
         true <- quantity > 0,
         {:ok, unit_price} <- to_decimal(Map.get(item, "unit_price")),
         true <- Decimal.compare(unit_price, Decimal.new(0)) != :lt do
      amount = Decimal.new(quantity) |> Decimal.mult(unit_price)

      {:ok,
       %{
         "description" => description,
         "quantity" => quantity,
         "unit_price" => unit_price,
         "amount" => amount
       }}
    else
      _ -> {:error, :invalid_line_item}
    end
  end

  defp prepare_line_item(_), do: {:error, :invalid_line_item}

  defp sum_amounts(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc -> Decimal.add(acc, item["amount"]) end)
  end

  defp next_invoice_number(%Business{} = business) do
    count = Repo.aggregate(from(i in Invoice, where: i.business_id == ^business.id), :count)
    "INV-" <> String.pad_leading(Integer.to_string(count + 1), 4, "0")
  end

  defp to_integer(v) when is_integer(v), do: {:ok, v}

  defp to_integer(v) when is_binary(v) do
    case Integer.parse(v) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp to_integer(_), do: :error

  defp to_decimal(%Decimal{} = d), do: {:ok, d}
  defp to_decimal(nil), do: {:ok, Decimal.new(0)}

  defp to_decimal(v) when is_binary(v) do
    case Decimal.parse(v) do
      {d, ""} -> {:ok, d}
      _ -> :error
    end
  end

  defp to_decimal(v) when is_integer(v), do: {:ok, Decimal.new(v)}
  defp to_decimal(v) when is_float(v), do: {:ok, Decimal.from_float(v)}
  defp to_decimal(_), do: :error
end
