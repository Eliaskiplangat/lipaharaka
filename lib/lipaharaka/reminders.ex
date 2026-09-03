defmodule Lipaharaka.Reminders do
  @moduledoc """
  The Reminders context: schedules and delivers escalating payment
  reminders for sent invoices.

  ## Schedule

  A fixed sequence, relative to the invoice's `due_date`:

      -2 days (before due) | 0 (due today) | +3 | +7 | +14 (overdue)

  This is NOT yet configurable per business — a real limitation, not
  an oversight. The FSD describes "configurable intervals" as the
  eventual goal; this fixed schedule is the MVP starting point.

  ## How delivery works

  Each reminder is a persisted `Lipaharaka.Reminders.Reminder` row,
  created (status `"scheduled"`) at the same time its corresponding
  Oban job is enqueued, at invoice-send time
  (`schedule_reminders_for_invoice/1`, called from
  `Lipaharaka.Invoicing.send_invoice/2`). When the job actually runs,
  potentially days later, `deliver_reminder/1` re-checks the
  invoice's CURRENT status:

    * still `"sent"` — send the SMS, mark the reminder `"sent"`.
    * anything else (`"paid"`, `"cancelled"`) — mark the reminder
      `"skipped"`. This is how a paid or cancelled invoice's remaining
      reminders are silently neutralized, without needing any job
      cancellation logic — every scheduled job still runs, it just
      finds there's nothing to do.

  This means `deliver_reminder/1` is fully testable on its own,
  without needing Oban's scheduler to actually fire — see
  `test/lipaharaka/reminders_test.exs`.
  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Invoicing
  alias Lipaharaka.Invoicing.Invoice
  alias Lipaharaka.Businesses.Business
  alias Lipaharaka.Reminders.{Reminder, Worker}

  @offsets [-2, 0, 3, 7, 14]

  @doc "The fixed reminder offsets (days relative to due_date) used for every invoice."
  def offsets, do: @offsets

  @doc """
  Creates a `Reminder` row and enqueues a corresponding Oban job for
  each offset in `offsets/0`, relative to the invoice's `due_date`.
  Called automatically by `Lipaharaka.Invoicing.send_invoice/2` — not
  meant to be called directly from a controller.
  """
  @spec schedule_reminders_for_invoice(Invoice.t()) :: :ok
  def schedule_reminders_for_invoice(%Invoice{} = invoice) do
    Enum.each(@offsets, fn offset ->
      scheduled_for = Date.add(invoice.due_date, offset)

      {:ok, reminder} =
        %Reminder{}
        |> Reminder.create_changeset(%{
          invoice_id: invoice.id,
          offset_days: offset,
          scheduled_for: scheduled_for
        })
        |> Repo.insert()

      scheduled_at = DateTime.new!(scheduled_for, ~T[08:00:00])

      %{reminder_id: reminder.id}
      |> Worker.new(scheduled_at: scheduled_at)
      |> Oban.insert()
    end)

    :ok
  end

  @doc """
  Delivers (or skips) a single reminder. Called by
  `Lipaharaka.Reminders.Worker` when its scheduled job runs, but is a
  plain function specifically so it can be tested directly without
  needing Oban's scheduler.
  """
  @spec deliver_reminder(Ecto.UUID.t()) :: {:ok, Reminder.t()} | {:error, term()}
  def deliver_reminder(reminder_id) do
    reminder = Repo.get!(Reminder, reminder_id)
    invoice = Invoicing.get_invoice_unscoped(reminder.invoice_id)

    cond do
      is_nil(invoice) or invoice.status != "sent" ->
        reminder |> Reminder.skipped_changeset() |> Repo.update()

      true ->
        message = compose_message(invoice, reminder.offset_days)

        case Lipaharaka.SMS.send(invoice.buyer_phone, message) do
          {:ok, _result} -> reminder |> Reminder.sent_changeset(message) |> Repo.update()
          {:error, _reason} -> reminder |> Reminder.failed_changeset() |> Repo.update()
        end
    end
  end

  @doc """
  Lists an invoice's reminder history, ordered earliest-scheduled
  first. Scoped through business ownership via
  `Lipaharaka.Invoicing.get_invoice_for_business/2` — returns
  `{:error, :not_found}` for an invoice that doesn't belong to the
  given business.
  """
  @spec list_reminders_for_invoice(Business.t(), String.t()) ::
          {:ok, [Reminder.t()]} | {:error, :not_found}
  def list_reminders_for_invoice(%Business{} = business, invoice_id) do
    case Invoicing.get_invoice_for_business(business, invoice_id) do
      nil ->
        {:error, :not_found}

      invoice ->
        reminders =
          Repo.all(from r in Reminder, where: r.invoice_id == ^invoice.id, order_by: [asc: r.offset_days])

        {:ok, reminders}
    end
  end

  defp compose_message(invoice, offset_days) do
    amount = Decimal.to_string(invoice.total, :normal)

    cond do
      offset_days < 0 ->
        "Reminder: Invoice #{invoice.invoice_number} for KES #{amount} is due on #{invoice.due_date}."

      offset_days == 0 ->
        "Invoice #{invoice.invoice_number} for KES #{amount} is due today."

      offset_days <= 7 ->
        "Invoice #{invoice.invoice_number} for KES #{amount} was due on #{invoice.due_date} and is now " <>
          "#{offset_days} day(s) overdue. Please settle at your earliest convenience."

      true ->
        "URGENT: Invoice #{invoice.invoice_number} for KES #{amount} is significantly overdue " <>
          "(#{offset_days} days). Please contact us immediately to arrange payment."
    end
  end
end
