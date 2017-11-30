defmodule Livevox.EventLoggers.AgentEvent do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn ->
      %{}
    end)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{}}
  end

  def handle_info(message = %{"lineNumber" => "ACD"}, state) do
    underscored =
      Enum.map(message, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(agent_id agent_service_id event_type timestamp) = underscored

    service_name = Livevox.ServiceInfo.name_of(agent_service_id)
    agent_name = Livevox.AgentInfo.name_of(agent_id)

    {:ok, timestamp} = DateTime.from_unix(timestamp, :millisecond)

    Dog.post_event(%{
      title: "agent_event:#{event_type}",
      date_happened: timestamp,
      tags: ["agent:#{agent_name}", "service:#{service_name}"]
    })

    Mongo.insert_one(:mongo, "agent_events", ~m(agent_name service_name event_type timestamp))

    {:noreply, %{}}
  end

  def handle_info(_, _) do
    {:noreply, %{}}
  end

  defp typey_downcase(val) when is_binary(val), do: String.downcase(val)
  defp typey_downcase(val), do: val
end
