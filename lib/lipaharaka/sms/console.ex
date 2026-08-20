defmodule Lipaharaka.SMS.Console do
  @moduledoc """

  """

  @behaviour Lipaharaka.SMS

  require Logger

  @impl true
  def send(phone_number, message) do
    Logger.info("[SMS/Console] To: #{phone_number} — #{message}")
    {:ok, %{recipients: [%{"number" => phone_number, "status" => "Success"}]}}
  end
end
