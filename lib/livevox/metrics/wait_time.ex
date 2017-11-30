defmodule Livevox.Metrics.WaitTime do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn -> %{} end)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{}}
  end

  def handle_info(message = %{"eventType" => "READY"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp} = message
    new_state = Map.put(state, agent_id, %{state: "READY", changed_at: timestamp})
    {:noreply, new_state}
  end

  def handle_info(message = %{"eventType" => "IN_CALL"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => agentServiceId} =
      message

    service_name = Livevox.ServiceInfo.name_of(agent_service_id)
    agent_name = Livevox.AgentInfo.name_of(agent_id)
    tags = ["agent:#{agent_name}", "service:#{service_name}"]

    # Side effects
    case Map.get(state, agent_id) do
      %{state: "READY", changed_at: ready_at} ->
        Dog.post_metric(
          "wait_time",
          [timestamp |> DateTime.to_unix(), Timex.diff(ready_at, timestamp)],
          tags
        )

      %{state: something_else, changed_at: prev_state_set_at} ->
        Dog.post_event(%{
          title: "error",
          text: "expected prev_state to be ready – was #{something_else} at #{prev_state_set_at}",
          date_happened: Timex.now(),
          tags: tags
        })
    end

    {:noreply, Map.put(state, agent_id, %{state: "IN_CALL", changed_at: timestamp})}
  end
end
