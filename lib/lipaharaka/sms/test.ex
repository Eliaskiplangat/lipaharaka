defmodule Lipaharaka.SMS.Test do
  @moduledoc """

  """

  @behaviour Lipaharaka.SMS

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @impl true
  def send(phone_number, message) do
    ensure_started()
    Agent.update(__MODULE__, fn messages -> [{phone_number, message} | messages] end)
    {:ok, %{recipients: [%{"number" => phone_number, "status" => "Success"}]}}
  end


  def sent_messages do
    ensure_started()
    Agent.get(__MODULE__, & &1)
  end


  def last_message_to(phone_number) do
    sent_messages()
    |> Enum.find(fn {to, _msg} -> to == phone_number end)
    |> case do
      {_to, message} -> message
      nil -> nil
    end
  end

  def clear do
    ensure_started()
    Agent.update(__MODULE__, fn _ -> [] end)
  end

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_link([])
      _pid -> :ok
    end
  end
end
