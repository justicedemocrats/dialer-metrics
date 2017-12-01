defmodule Livevox.Metrics.SessionLength do
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

  def handle_info(message = %{"eventType" => "LOGON"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp} = message
    {:ok, logged_on_at} = DateTime.from_unix(timestamp, :millisecond)
    {:noreply, Map.put(state, agent_id, logged_on_at)}
  end

  def handle_info(message = %{"eventType" => "LOGOFF"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => agent_service_id} =
      message

    service_name = Livevox.ServiceInfo.name_of(agent_service_id)
    agent_name = Livevox.AgentInfo.name_of(agent_id)
    tags = ["agent:#{agent_name}", "service:#{service_name}"]
    {:ok, timestamp} = DateTime.from_unix(timestamp, :millisecond)

    if Map.has_key?(state, agent_id) do
      logged_on_at = Map.get(state, agent_id)

      spawn(fn ->
        Dog.post_metric(
          "session_length",
          [timestamp, Timex.diff(timestamp, logged_on_at) / 10_000_000],
          tags
        )
      end)
    else
      spawn(fn ->
        Dog.post_event(%{
          title: "error",
          text: "got log off for #{agent_id} but never got log on",
          date_happened: Timex.now(),
          tags: tags
        })
      end)
    end

    {:noreply, Map.drop(state, [agent_id])}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
