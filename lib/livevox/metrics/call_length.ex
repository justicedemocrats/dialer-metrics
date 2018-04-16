defmodule Livevox.Metrics.CallLength do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(
      __MODULE__,
      fn ->
        %{}
      end,
      name: __MODULE__
    )
  end

  def init(_opts) do
    PubSub.subscribe(:livevox, "call_event")
    {:ok, %{}}
  end

  def handle_info(
        message = %{"lvResult" => "Operator Transfer" <> _rest},
        state
      ) do
    underscored =
      Enum.map(message, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(duration agent_login_id service_id) = underscored

    service_name = Livevox.ServiceInfo.name_of(service_id)
    agent_name = agent_login_id
    tags = ["agent:#{agent_name}", "service:#{service_name}"]

    {:ok, timestamp} = DateTime.from_unix(underscored["end"], :millisecond)

    if duration > 0 do
      spawn(fn -> Dog.post_metric("call_length", [timestamp, duration], tags) end)
    end

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp typey_downcase(val) when is_binary(val), do: String.downcase(val)
  defp typey_downcase(val), do: val
end
