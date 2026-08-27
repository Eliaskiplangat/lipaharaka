defmodule Lipaharaka.Invoicing.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft sent paid cancelled)

  schema "invoices" do
    field :invoice_number, :string

    field :buyer_name, :string
    field :buyer_phone, :string
    field :buyer_email, :string

    field :issue_date, :date
    field :due_date, :date

    field :status, :string, default: "draft"

    field :subtotal, :decimal
    field :tax_rate, :decimal, default: Decimal.new(0)
    field :tax_amount, :decimal
    field :total, :decimal

    field :notes, :string

    field :sent_at, :utc_datetime
    field :paid_at, :utc_datetime
    field :cancelled_at, :utc_datetime

    belongs_to :business, Lipaharaka.Businesses.Business

    # on_replace: :delete — required so that updating an invoice with
    # a fresh set of line items (Lipaharaka.Invoicing.update_invoice/3)
    # can cleanly drop the old rows and insert the new ones via
    # cast_assoc, rather than Ecto raising because some previously
    # existing line items aren't present in the new list.
    has_many :line_items, Lipaharaka.Invoicing.LineItem, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          business_id: Ecto.UUID.t() | nil,
          invoice_number: String.t() | nil,
          buyer_name: String.t() | nil,
          buyer_phone: String.t() | nil,
          buyer_email: String.t() | nil,
          issue_date: Date.t() | nil,
          due_date: Date.t() | nil,
          status: String.t(),
          subtotal: Decimal.t() | nil,
          tax_rate: Decimal.t(),
          tax_amount: Decimal.t() | nil,
          total: Decimal.t() | nil,
          notes: String.t() | nil,
          sent_at: DateTime.t() | nil,
          paid_at: DateTime.t() | nil,
          cancelled_at: DateTime.t() | nil
        }

  def statuses, do: @statuses

  @doc """
  Changeset for creating an invoice. Expects `business_id`,
  `invoice_number`, `subtotal`, `tax_amount`, and `total` to already
  be present in `attrs` — all computed server-side by
  `Lipaharaka.Invoicing.create_invoice/2` before this changeset runs.
  Never trust these fields from the client directly.
  """
  def create_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :business_id,
      :invoice_number,
      :buyer_name,
      :buyer_phone,
      :buyer_email,
      :issue_date,
      :due_date,
      :tax_rate,
      :subtotal,
      :tax_amount,
      :total,
      :notes
    ])
    |> validate_required([
      :business_id,
      :invoice_number,
      :buyer_name,
      :buyer_phone,
      :issue_date,
      :due_date,
      :subtotal,
      :tax_amount,
      :total
    ])
    |> validate_length(:buyer_name, min: 1, max: 160)
    |> validate_due_date_after_issue_date()
    |> cast_assoc(:line_items, with: &Lipaharaka.Invoicing.LineItem.changeset/2, required: true)
    |> foreign_key_constraint(:business_id)
    |> unique_constraint([:business_id, :invoice_number])
  end

  @doc """
  Changeset for updating a draft invoice's buyer/date/notes fields
  ONLY — does not touch line items or totals. Used when a
  `PATCH /api/invoices/:id` request doesn't include `line_items`.
  """
  def update_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [:buyer_name, :buyer_phone, :buyer_email, :issue_date, :due_date, :notes])
    |> validate_length(:buyer_name, min: 1, max: 160)
    |> validate_due_date_after_issue_date()
  end

  @doc """
  Changeset for updating a draft invoice INCLUDING a fresh set of line
  items — same shape as `create_changeset/2`, minus `business_id` and
  `invoice_number` (which never change after creation). Used when a
  `PATCH /api/invoices/:id` request includes `line_items`; totals are
  recomputed server-side the same way as on creation, never trusted
  from the client.
  """
  def replace_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :buyer_name,
      :buyer_phone,
      :buyer_email,
      :issue_date,
      :due_date,
      :notes,
      :tax_rate,
      :subtotal,
      :tax_amount,
      :total
    ])
    |> validate_length(:buyer_name, min: 1, max: 160)
    |> validate_due_date_after_issue_date()
    |> cast_assoc(:line_items, with: &Lipaharaka.Invoicing.LineItem.changeset/2, required: true)
  end

  @doc false
  def status_changeset(invoice, "sent") do
    change(invoice, status: "sent", sent_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def status_changeset(invoice, "paid") do
    change(invoice, status: "paid", paid_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def status_changeset(invoice, "cancelled") do
    change(invoice, status: "cancelled", cancelled_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp validate_due_date_after_issue_date(changeset) do
    issue_date = get_field(changeset, :issue_date)
    due_date = get_field(changeset, :due_date)

    if issue_date && due_date && Date.compare(due_date, issue_date) == :lt do
      add_error(changeset, :due_date, "cannot be before the issue date")
    else
      changeset
    end
  end
end
