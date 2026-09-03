defmodule Lipaharaka.SMS do


  @type phone_number :: String.t()
  @type message :: String.t()

  @callback send(phone_number(), message()) :: {:ok, map()} | {:error, term()}

  @spec send(phone_number(), message()) :: {:ok, map()} | {:error, term()}
  def send(phone_number, message) do
    adapter().send(phone_number, message)
  end

  defp adapter do
    Application.get_env(:lipaharaka, :sms_adapter, Lipaharaka.SMS.Console)
  end
end
