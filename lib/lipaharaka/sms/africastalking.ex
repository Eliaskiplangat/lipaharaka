defmodule Lipaharaka.SMS.AfricasTalking do
  @moduledoc """

  """

  @behaviour Lipaharaka.SMS

  @impl true
  def send(phone_number, message) do
    config = Application.fetch_env!(:lipaharaka, :africas_talking)
    base_url = config[:base_url] || "https://api.sandbox.africastalking.com"

    body =
      %{
        "username" => Keyword.fetch!(config, :username),
        "to" => phone_number,
        "message" => message
      }
      |> maybe_put_sender_id(config[:sender_id])

    request =
      Req.new(
        base_url: base_url,
        headers: [
          {"apiKey", Keyword.fetch!(config, :api_key)},
          {"accept", "application/json"}
        ],
        form: body
      )

    case Req.post(request, url: "/version1/messaging") do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        case parse_recipients(response_body) do
          {:ok, _recipients} = ok -> ok
          {:error, _reason} = err -> err
        end

      {:ok, %{status: status, body: response_body}} ->
        {:error, {:unexpected_status, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_put_sender_id(body, nil), do: body
  defp maybe_put_sender_id(body, sender_id), do: Map.put(body, "from", sender_id)

  defp parse_recipients(%{"SMSMessageData" => %{"Recipients" => recipients}}) do
    case Enum.find(recipients, fn r -> r["status"] != "Success" end) do
      nil -> {:ok, %{recipients: recipients}}
      failed -> {:error, {:recipient_failed, failed}}
    end
  end

  defp parse_recipients(other), do: {:error, {:unexpected_response, other}}
end
