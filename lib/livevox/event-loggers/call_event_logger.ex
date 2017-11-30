defmodule Livevox.Events.CallEvent do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn ->
      %{}
    end)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "call_event")
    {:ok, %{}}
  end

  def handle_info(message, state) do
    underscored =
      Enum.map(message, fn {key, val} -> {Macro.underscore(key), String.downcase(val)} end)
      |> Enum.into(%{})

    {:ok, timestamp} = DateTime.from_unix(timestamp, :millisecond)

    # Dog.post_event(%{
    #   title: "agent_event:#{event_type}",
    #   date_happened: timestamp,
    #   tags: ["agent:#{agent_name}", "service:#{service_name}"]
    # })

    # Mongo.insert_one(:mongo, "agent_events", ~m(agent_name service_name event_type timestamp))

    {:noreply, %{}}
  end

  def handle_info(_, _) do
    {:noreply, %{}}
  end
end
