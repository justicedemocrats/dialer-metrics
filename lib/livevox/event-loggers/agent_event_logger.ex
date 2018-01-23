defmodule Livevox.EventLoggers.AgentEvent do
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
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{}}
  end

  def handle_info(message = %{"lineNumber" => "ACD"}, state) do
    Db.insert_one("agent_raw", message)
    new_state = record_and_store_event(message, state)
    {:noreply, new_state}
  end

  def handle_info(message = %{"eventType" => "LOGON"}, state) do
    Db.insert_one("agent_raw", message)
    new_state = record_and_store_event(message, state)
    {:noreply, new_state}
  end

  def handle_info(message = %{"eventType" => "LOGOFF"}, state) do
    Db.insert_one("agent_raw", message)
    new_state = record_and_store_event(message, state)
    {:noreply, new_state}
  end

  def record_and_store_event(message, state) do
    underscored =
      Enum.map(message, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(agent_id agent_service_id event_type timestamp) = underscored

    service_name = Livevox.ServiceInfo.name_of(agent_service_id)
    agent_name = Livevox.AgentInfo.name_of(agent_id)

    {:ok, timestamp} = DateTime.from_unix(timestamp, :millisecond)

    metric_title = "agent_event:#{event_type}"

    caller_attributes = Livevox.AgentInfo.get_caller_attributes(service_name, agent_name)

    spawn(fn ->
      Dog.post_event(%{
        title: metric_title,
        date_happened: timestamp,
        tags: [
          "agent:#{agent_name}",
          "service:#{service_name}",
          "caller_email:#{caller_attributes["caller_email"]}",
          "calling_from:#{caller_attributes["calling_from"]}"
        ]
      })
    end)

    spawn(fn ->
      Db.insert_one(
        "agent_events",
        Map.merge(~m(agent_name service_name event_type timestamp), caller_attributes)
      )
    end)

    # For inc state
    matchers =
      Map.values(~m(service_name event_type metric_title))
      |> MapSet.new()

    inc_state(state, matchers)
  end

  def handle_info(message, state) do
    Db.insert_one("agent_raw", message)
    {:noreply, state}
  end

  defp inc_state(state, matchers) do
    Map.update(state, matchers, 1, &(&1 + 1))
  end

  # Flush – post current state as a metric
  def flush do
    state = :sys.get_state(__MODULE__)

    now = DateTime.utc_now() |> DateTime.to_unix()

    series =
      Enum.map(state, fn {tag_set, count} ->
        metric_title =
          Enum.filter(tag_set, fn tag -> String.contains?(tag, "agent_event:") end)
          |> List.first()

        tags = Enum.reject(tag_set, fn tag -> String.contains?(tag, "agent_event:") end)
        %{metric: metric_title, points: [[now, count]], tags: tags}
      end)

    if length(series) > 0 do
      Dog.post_metrics(series)
    end

    # No reply (just for side effects), and reset state
    {:noreply, %{}}
  end

  defp typey_downcase(val) when is_binary(val), do: String.downcase(val)
  defp typey_downcase(val), do: val
end
