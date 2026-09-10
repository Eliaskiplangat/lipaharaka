defmodule Lipaharaka.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mpesa_payments" do
    field :checkout_request_id, :string
    field :merchant_request_id, :string
    field :phone_number, :string
    field :amount, :decimal
    field :status, :string, default: "pending"
    field :mpesa_receipt_number, :string
    field :result_code, :integer
    field :result_desc, :string
    field :raw_callback, :map

    belongs_to :invoice, Lipaharaka.Invoicing.Invoice

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          invoice_id: Ecto.UUID.t() | nil,
          checkout_request_id: String.t() | nil,
          merchant_request_id: String.t() | nil,
          phone_number: String.t() | nil,
          amount: Decimal.t() | nil,
          status: String.t(),
          mpesa_receipt_number: String.t() | nil,
          result_code: integer() | nil,
          result_desc: String.t() | nil,
          raw_callback: map() | nil
        }

  @doc "Changeset for creating a payment record right after a successful STK Push request."
  def create_changeset(payment, attrs) do
    payment
    |> cast(attrs, [:invoice_id, :checkout_request_id, :merchant_request_id, :phone_number, :amount])
    |> validate_required([:invoice_id, :checkout_request_id, :phone_number, :amount])
    |> foreign_key_constraint(:invoice_id)
    |> unique_constraint(:checkout_request_id)
  end

  @doc "Changeset applied when Safaricom's callback reports success (ResultCode 0)."
  def success_changeset(payment, attrs) do
    payment
    |> cast(attrs, [:mpesa_receipt_number, :result_code, :result_desc, :raw_callback])
    |> put_change(:status, "success")
  end

  @doc "Changeset applied when Safaricom's callback reports a non-zero ResultCode (failed/cancelled)."
  def failed_changeset(payment, attrs) do
    payment
    |> cast(attrs, [:result_code, :result_desc, :raw_callback])
    |> put_change(:status, "failed")
  end
end
