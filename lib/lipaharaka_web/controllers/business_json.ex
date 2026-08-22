defmodule LipaharakaWeb.BusinessJSON do
  alias Lipaharaka.Businesses.Business

  def show(%{business: business}) do
    %{business: business_summary(business)}
  end

  def changeset_error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp business_summary(%Business{} = business) do
    %{
      id: business.id,
      business_name: business.business_name,
      registration_number: business.registration_number,
      kra_pin: business.kra_pin,
      sector: business.sector,
      mpesa_till_or_paybill: business.mpesa_till_or_paybill,
      kyc_status: business.kyc_status
    }
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
