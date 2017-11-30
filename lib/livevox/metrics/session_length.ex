defmodule Livevox.Metrics.CallerCounts do
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
    {:noreply, Map.put(state, agent_id, Timex.now())}
  end

  def handle_info(message = %{"eventType" => "LOGOFF"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => agentServiceId} =
      message

    tags = ["agent:#{agent_id}", "service:#{Livevox.ServiceInfo.name_of(agentServiceId)}"]

    if Map.has_key?(state, agent_id) do
      logged_on_at = Map.get(state, agent_id)

      Dog.post_metric(
        "session_length",
        [timestamp |> DateTime.to_unix(), Timex.diff(logged_on_at, timestamp)],
        tags
      )
    else
      Dog.post_event(%{
        title: "error",
        text: "got log off for #{agent_id} but never got log on",
        date_happened: DateTime.now(),
        tags: tags
      })
    end

    {:noreply, Map.drop(state, [agent_id])}
  end
end
