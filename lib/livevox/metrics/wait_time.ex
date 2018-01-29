defmodule Livevox.Metrics.WaitTime do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn -> %{} end, name: __MODULE__)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{}}
  end

  def handle_info(message = %{"eventType" => "READY", "lineNumber" => "ACD"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp} = message
    {:ok, timestamp} = DateTime.from_unix(timestamp, :millisecond)
    new_state = Map.put(state, agent_id, %{state: "READY", changed_at: timestamp})
    {:noreply, new_state}
  end

  def handle_info(message = %{"eventType" => "IN_CALL"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => agent_service_id} =
      message

    service_name = Livevox.ServiceInfo.name_of(agent_service_id)
    agent_name = Livevox.AgentInfo.name_of(agent_id)
    tags = ["agent:#{agent_name}", "service:#{service_name}"]
    {:ok, timestamp} = DateTime.from_unix(timestamp, :millisecond)

    # Side effects
    case Map.get(state, agent_id) do
      %{state: "READY", changed_at: ready_at} ->
        spawn(fn ->
          Dog.post_metric(
            "wait_time",
            [timestamp, Timex.diff(timestamp, ready_at) / 1_000_000],
            tags
          )
        end)

      %{state: something_else, changed_at: prev_state_set_at} ->
        spawn(fn ->
          Dog.post_event(%{
            title: "error",
            text:
              "expected prev_state to be ready – was #{something_else} at #{prev_state_set_at}",
            date_happened: Timex.now(),
            tags: tags
          })
        end)

      nil ->
        spawn(fn ->
          Dog.post_event(%{
            title: "error",
            text: "expected prev_state to be ready – was nil",
            date_happened: Timex.now(),
            tags: tags
          })
        end)
    end

    {:noreply, Map.put(state, agent_id, %{state: "IN_CALL", changed_at: timestamp})}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
