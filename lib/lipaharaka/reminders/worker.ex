defmodule Lipaharaka.Reminders.Worker do
  @moduledoc """
  Oban worker that delivers a single scheduled reminder.

  Deliberately thin — all real logic lives in
  `Lipaharaka.Reminders.deliver_reminder/1`, which is directly
  testable without touching Oban at all. This module's only job is
  translating between Oban's job-argument contract and that function.
  """

  use Oban.Worker, queue: :reminders, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"reminder_id" => reminder_id}}) do
    case Lipaharaka.Reminders.deliver_reminder(reminder_id) do
      {:ok, _reminder} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
