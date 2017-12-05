defmodule Livevox.EventLoggers.CallEvent do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  @flush_resolution 30_000

  def start_link do
    GenServer.start_link(__MODULE__, fn ->
      %{}
    end, name: __MODULE__)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "call_event")
    queue_flush()
    {:ok, %{}}
  end

  def queue_flush do
    spawn(fn ->
      :timer.sleep(@flush_resolution)
      GenServer.cast(__MODULE__, :flush)
      queue_flush()
    end)
  end

  def handle_info(message, state) do
    underscored =
      Enum.map(message, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(
      client_id transaction_id session_id duration agent_login_id
      phone_dialed service_id
    ) = underscored

    agent_name = agent_login_id
    service_name = Livevox.ServiceInfo.name_of(service_id)

    agent_result =
      get_agent_result(session_id, transaction_id, client_id)
      |> Enum.map(fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    lv_result = agent_result["lv_result"] || underscored["lv_result"]

    extra_attributes = Livevox.AirtableCache.get_all() |> Map.get(lv_result)

    actor_tags =
      case agent_name do
        "" -> ["service:#{service_name}"]
        nil -> ["service:#{service_name}"]
        agent_name -> ["agent:#{agent_name}", "service:#{service_name}"]
      end

    tags =
      Enum.filter(extra_attributes, fn
        {key, val} when is_boolean(val) -> val
        {key, val} -> val != ""
      end)
      |> Enum.map(fn
           {key, val} when is_boolean(val) -> key
           {key, val} -> "#{key}:#{val}"
         end)
      |> Enum.concat(actor_tags)

    {:ok, timestamp} = DateTime.from_unix(underscored["end"], :millisecond)

    # Record the event
    spawn(fn ->
      Dog.post_event(%{
        title: "call",
        date_happened: timestamp,
        tags: tags
      })
    end)

    # For mongo
    call =
      Map.merge(~m(agent_name service_name duration phone_dialed lv_result), extra_attributes)
    spawn(fn -> Mongo.insert_one(:mongo, "calls", Map.merge(call, ~m(timestamp))) end)

    # For inc state
    matchers =
      Map.merge(~m(service_name lv_result), extra_attributes)
      |> Map.values()
      |> MapSet.new()

    {:noreply, inc_state(state, matchers)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp inc_state(state, matchers) do
    Map.update(state, matchers, 1, & &1 + 1)
  end

  # Flush – post current state as a metric,
  defp handle_cast(:flush, state) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    series = Enum.map(state, fn {tag_set, count} ->
      %{metric: "call_count", points: [[now, count]], tags: MapSet.to_list(tag_set)}
    end)

    if length(series) > 0 do
      Dog.post_metrics(series)
    end

    # No reply (just for side effects), and reset state
    {:noreply, %{}}
  end

  defp typey_downcase(val) when is_binary(val), do: String.downcase(val)
  defp typey_downcase(val), do: val

  defp get_agent_result(session_id, transaction_id, client_id) do
    %{body: body} =
      Livevox.Api.get("realtime/v5.0/callData/postCall", query: %{
        clientId: client_id,
        transaction: transaction_id,
        session: session_id
      })

    body
  end
end
