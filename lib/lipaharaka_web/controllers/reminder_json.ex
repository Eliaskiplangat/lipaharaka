defmodule LipaharakaWeb.ReminderJSON do
  alias Lipaharaka.Reminders.Reminder

  def index(%{reminders: reminders}) do
    %{reminders: Enum.map(reminders, &reminder_summary/1)}
  end

  defp reminder_summary(%Reminder{} = reminder) do
    %{
      id: reminder.id,
      offset_days: reminder.offset_days,
      scheduled_for: reminder.scheduled_for,
      status: reminder.status,
      channel: reminder.channel,
      message: reminder.message,
      sent_at: reminder.sent_at
    }
  end
end
