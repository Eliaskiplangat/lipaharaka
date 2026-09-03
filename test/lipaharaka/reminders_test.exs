defmodule Lipaharaka.RemindersTest do
  use Lipaharaka.DataCase, async: false
  use Oban.Testing, repo: Lipaharaka.Repo

  alias Lipaharaka.{Accounts, Businesses, Invoicing, Reminders}
  alias Lipaharaka.Reminders.{Reminder, Worker}

  @invoice_attrs %{
    "buyer_name" => "Zuri Retail Ltd",
    "buyer_phone" => "0798765432",
    "issue_date" => "2026-08-12",
    "due_date" => "2026-08-26",
    "line_items" => [%{"description" => "Office desks", "quantity" => 8, "unit_price" => "6500.00"}]
  }

  setup do
    Lipaharaka.SMS.Test.clear()
    {:ok, user} = Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})
    {:ok, business} = Businesses.create_business(user, %{"business_name" => "Jaza Traders Ltd"})
    {:ok, invoice} = Invoicing.create_invoice(business, @invoice_attrs)
    %{business: business, invoice: invoice}
  end

  describe "schedule_reminders_for_invoice/1 (via send_invoice/2)" do
    test "creates a Reminder row for each offset", %{business: business, invoice: invoice} do
      {:ok, sent} = Invoicing.send_invoice(business, invoice.id)

      reminders = Repo.all(Reminder) |> Enum.filter(&(&1.invoice_id == sent.id))
      offsets = reminders |> Enum.map(& &1.offset_days) |> Enum.sort()

      assert offsets == Enum.sort(Reminders.offsets())
      assert Enum.all?(reminders, &(&1.status == "scheduled"))
    end

    test "sets scheduled_for correctly relative to due_date", %{business: business, invoice: invoice} do
      {:ok, sent} = Invoicing.send_invoice(business, invoice.id)

      reminder = Repo.get_by!(Reminder, invoice_id: sent.id, offset_days: 3)
      assert reminder.scheduled_for == Date.add(sent.due_date, 3)
    end

    test "enqueues a corresponding Oban job for each reminder", %{business: business, invoice: invoice} do
      {:ok, sent} = Invoicing.send_invoice(business, invoice.id)

      reminders = Repo.all(Reminder) |> Enum.filter(&(&1.invoice_id == sent.id))

      for reminder <- reminders do
        assert_enqueued worker: Worker, args: %{reminder_id: reminder.id}
      end
    end
  end

  describe "deliver_reminder/1" do
    test "sends an SMS and marks the reminder sent when the invoice is still sent", %{
      business: business,
      invoice: invoice
    } do
      {:ok, sent_invoice} = Invoicing.send_invoice(business, invoice.id)
      reminder = Repo.get_by!(Reminder, invoice_id: sent_invoice.id, offset_days: 0)

      assert {:ok, delivered} = Reminders.deliver_reminder(reminder.id)
      assert delivered.status == "sent"
      refute is_nil(delivered.sent_at)

      message = Lipaharaka.SMS.Test.last_message_to(sent_invoice.buyer_phone)
      assert message =~ sent_invoice.invoice_number
      assert message =~ "due today"
    end

    test "skips (does not send) when the invoice has already been paid", %{business: business, invoice: invoice} do
      {:ok, sent_invoice} = Invoicing.send_invoice(business, invoice.id)
      {:ok, _paid} = Invoicing.mark_paid(business, sent_invoice.id)

      reminder = Repo.get_by!(Reminder, invoice_id: sent_invoice.id, offset_days: 7)
      Lipaharaka.SMS.Test.clear()

      assert {:ok, delivered} = Reminders.deliver_reminder(reminder.id)
      assert delivered.status == "skipped"
      assert Lipaharaka.SMS.Test.last_message_to(sent_invoice.buyer_phone) == nil
    end

    test "skips when the invoice has been cancelled", %{business: business, invoice: invoice} do
      {:ok, sent_invoice} = Invoicing.send_invoice(business, invoice.id)
      {:ok, _cancelled} = Invoicing.cancel_invoice(business, sent_invoice.id)

      reminder = Repo.get_by!(Reminder, invoice_id: sent_invoice.id, offset_days: -2)
      assert {:ok, delivered} = Reminders.deliver_reminder(reminder.id)
      assert delivered.status == "skipped"
    end

    test "message tone escalates with larger positive offsets", %{business: business, invoice: invoice} do
      {:ok, sent_invoice} = Invoicing.send_invoice(business, invoice.id)

      before_due = Repo.get_by!(Reminder, invoice_id: sent_invoice.id, offset_days: -2)
      moderately_overdue = Repo.get_by!(Reminder, invoice_id: sent_invoice.id, offset_days: 7)
      very_overdue = Repo.get_by!(Reminder, invoice_id: sent_invoice.id, offset_days: 14)

      {:ok, _} = Reminders.deliver_reminder(before_due.id)
      assert Lipaharaka.SMS.Test.last_message_to(sent_invoice.buyer_phone) =~ "Reminder:"

      {:ok, _} = Reminders.deliver_reminder(moderately_overdue.id)
      assert Lipaharaka.SMS.Test.last_message_to(sent_invoice.buyer_phone) =~ "overdue"

      {:ok, _} = Reminders.deliver_reminder(very_overdue.id)
      assert Lipaharaka.SMS.Test.last_message_to(sent_invoice.buyer_phone) =~ "URGENT"
    end
  end

  describe "list_reminders_for_invoice/2" do
    test "returns reminders ordered by offset_days for the owning business", %{business: business, invoice: invoice} do
      {:ok, sent_invoice} = Invoicing.send_invoice(business, invoice.id)

      assert {:ok, reminders} = Reminders.list_reminders_for_invoice(business, sent_invoice.id)
      assert Enum.map(reminders, & &1.offset_days) == Enum.sort(Reminders.offsets())
    end

    test "returns :not_found for another business's invoice", %{business: business, invoice: invoice} do
      {:ok, _sent} = Invoicing.send_invoice(business, invoice.id)

      {:ok, other_user} =
        Accounts.register_user(%{"phone_number" => "0700111222", "password" => "supersecret"})

      {:ok, other_business} = Businesses.create_business(other_user, %{"business_name" => "Other Co"})

      assert {:error, :not_found} = Reminders.list_reminders_for_invoice(other_business, invoice.id)
    end
  end
end
