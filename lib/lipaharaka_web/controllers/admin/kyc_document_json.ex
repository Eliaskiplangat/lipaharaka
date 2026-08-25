defmodule LipaharakaWeb.Admin.KycDocumentJSON do
  alias Lipaharaka.Businesses.KycDocument

  def pending(%{documents: documents}) do
    %{documents: Enum.map(documents, &document_with_business/1)}
  end

  def reviewed(%{document: document}) do
    %{document: document_with_business(document)}
  end

  defp document_with_business(%KycDocument{} = document) do
    %{
      id: document.id,
      document_type: document.document_type,
      original_filename: document.original_filename,
      status: document.status,
      review_note: document.review_note,
      uploaded_at: document.inserted_at,
      reviewed_at: document.reviewed_at,
      business: %{
        id: document.business.id,
        business_name: document.business.business_name,
        kyc_status: document.business.kyc_status,
        owner_phone_number: document.business.user.phone_number
      }
    }
  end
end
