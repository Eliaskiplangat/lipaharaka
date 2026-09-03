defmodule Lipaharaka.Reminders.Reminder do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(scheduled sent skipped failed)

  schema "reminders" do
    field :offset_days, :integer
    field :scheduled_for, :date
    field :status, :string, default: "scheduled"
    field :channel, :string, default: "sms"
    field :message, :string
    field :sent_at, :utc_datetime

    belongs_to :invoice, Lipaharaka.Invoicing.Invoice

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          invoice_id: Ecto.UUID.t() | nil,
          offset_days: integer() | nil,
          scheduled_for: Date.t() | nil,
          status: String.t(),
          channel: String.t(),
          message: String.t() | nil,
          sent_at: DateTime.t() | nil
        }

  def statuses, do: @statuses

  @doc "Changeset for creating a scheduled reminder row."
  def create_changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:invoice_id, :offset_days, :scheduled_for])
    |> validate_required([:invoice_id, :offset_days, :scheduled_for])
    |> foreign_key_constraint(:invoice_id)
  end

  @doc "Changeset applied when a reminder is actually sent."
  def sent_changeset(reminder, message) do
    change(reminder,
      status: "sent",
      message: message,
      sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
  end

  @doc "Changeset applied when a reminder is skipped (invoice no longer sent, e.g. already paid)."
  def skipped_changeset(reminder) do
    change(reminder, status: "skipped")
  end

  @doc "Changeset applied when sending genuinely failed (e.g. SMS provider error)."
  def failed_changeset(reminder) do
    change(reminder, status: "failed")
  end
end
