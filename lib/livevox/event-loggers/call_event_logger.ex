defmodule Livevox.EventLoggers.CallEvent do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def login_management_url, do: Application.get_env(:livevox, :login_management_url)

  def start_link do
    GenServer.start_link(
      __MODULE__,
      fn ->
        %{}
      end,
      name: __MODULE__
    )
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "call_event")
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{}}
  end

  # Successful calls from agent event feed -> Data Dog
  def handle_info(
        message = %{"lineNumber" => "ACD", "eventType" => "WRAP_UP", "result" => _},
        state
      ) do
    Db.insert_one("calls_raw", message)

    ~m(service_name agent_name extra_attributes caller_attributes timestamp lv_result) =
      call = Livevox.EventLoggers.ProcessCall.from_agent_halfway(message)

    actor_tags =
      case agent_name do
        "" -> ["service:#{service_name}"]
        nil -> ["service:#{service_name}"]
        agent_name -> ["agent:#{agent_name}", "service:#{service_name}"]
      end

    tags =
      Livevox.EventLoggers.ProcessCall.tagify(extra_attributes)
      |> Enum.concat(actor_tags)
      |> Enum.concat(["lv_result:#{lv_result}"])

    # Record the event
    spawn(fn ->
      Dog.post_event(%{
        title: "call",
        date_happened: timestamp,
        tags: tags
      })
    end)

    # For inc state
    matchers =
      Map.values(~m(service_name lv_result))
      |> Enum.concat(tags)
      |> MapSet.new()

    {:noreply, inc_state(state, matchers)}
  end

  # If it's got an agent id, we'll get it through the agent event feed
  def handle_info(message = %{"lvResult" => _, "agentId" => agent_id}, state)
      when not is_nil(agent_id) do
    Db.insert_one("calls_raw", message)
    {:noreply, state}
  end

  # Calls from call event feed with no agent
  def handle_info(message = %{"lvResult" => _something}, state) do
    Db.insert_one("calls_raw", message)

    ~m(id service_name agent_name extra_attributes lv_result timestamp phone_dialed) =
      call = Livevox.EventLoggers.ProcessCall.from_call_halfway(message)

    actor_tags =
      case agent_name do
        "" -> ["service:#{service_name}"]
        nil -> ["service:#{service_name}"]
        agent_name -> ["agent:#{agent_name}", "service:#{service_name}"]
      end

    tags =
      Livevox.EventLoggers.ProcessCall.tagify(extra_attributes)
      |> Enum.concat(actor_tags)
      |> Enum.concat(["lv_result:#{lv_result}"])

    # Record the event
    spawn(fn ->
      Dog.post_event(%{
        title: "call",
        date_happened: timestamp,
        tags: tags
      })
    end)

    # For inc state
    matchers =
      Map.values(~m(service_name lv_result))
      |> Enum.concat(tags)
      |> MapSet.new()

    for_mongo =
      ~m(service_name agent_name lv_result timestamp phone_dialed duration service_id)
      |> Map.merge(extra_attributes)

    Db.update("calls", ~m(id), for_mongo)

    {:noreply, inc_state(state, matchers)}
  end

  def handle_info(message, state) do
    Db.insert_one("calls_raw", message)
    {:noreply, state}
  end

  defp inc_state(state, matchers) do
    Map.update(state, matchers, 1, &(&1 + 1))
  end

  # Flush – post current state as a metric,
  def flush do
    state = :sys.get_state(__MODULE__)
    now = DateTime.utc_now() |> DateTime.to_unix()

    series =
      Enum.map(state, fn {tag_set, count} ->
        %{metric: "call_count", points: [[now, count]], tags: MapSet.to_list(tag_set)}
      end)

    if length(series) > 0 do
      Dog.post_metrics(series)
    end

    # No reply (just for side effects), and reset state
    {:noreply, %{}}
  end
end
