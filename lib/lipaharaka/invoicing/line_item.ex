defmodule Lipaharaka.Invoicing.LineItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "invoice_line_items" do
    field :description, :string
    field :quantity, :integer
    field :unit_price, :decimal
    field :amount, :decimal

    belongs_to :invoice, Lipaharaka.Invoicing.Invoice

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          invoice_id: Ecto.UUID.t() | nil,
          description: String.t() | nil,
          quantity: integer() | nil,
          unit_price: Decimal.t() | nil,
          amount: Decimal.t() | nil
        }

  @doc """
  Changeset for a line item. Expects `amount` to already be present in
  `attrs` — it is computed server-side by
  `Lipaharaka.Invoicing.prepare_line_items/1` BEFORE this changeset
  ever runs, not derived here, so this changeset only casts and
  validates rather than doing arithmetic on data it can't fully trust
  yet (a nested changeset inside `cast_assoc` is a more awkward place
  to safely do that computation than a plain function is).
  """
  def changeset(line_item, attrs) do
    line_item
    |> cast(attrs, [:description, :quantity, :unit_price, :amount])
    |> validate_required([:description, :quantity, :unit_price, :amount])
    |> validate_length(:description, min: 1, max: 200)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
  end
end
