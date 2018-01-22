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

  # Successful calls from agent event feed
  def handle_info(
        message = %{"lineNumber" => "ACD", "eventType" => "WRAP_UP", "result" => _},
        state
      ) do
    Db.insert_one("calls_raw", message)

    underscored =
      Enum.map(message, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(
      client_id transaction_id session_id agent_id
      phone_number call_service_id result
    ) = underscored

    phone_dialed = phone_number
    lv_result = Livevox.Standardize.term_code(result)
    service_id = call_service_id

    agent_name = Livevox.AgentInfo.name_of(agent_id)
    service_name = Livevox.ServiceInfo.name_of(service_id)

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
      |> Enum.concat(["lv_result:#{lv_result}"])

    {:ok, timestamp} = DateTime.from_unix(underscored["timestamp"], :millisecond)

    # Record the event
    spawn(fn ->
      Dog.post_event(%{
        title: "call",
        date_happened: timestamp,
        tags: tags
      })
    end)

    # For mongo
    client_name = Livevox.ClientInfo.get_client_name(service_name)
    caller_email = get_caller_email(service_name, agent_name)

    call =
      Map.merge(~m(agent_name service_name phone_dialed lv_result caller_email), extra_attributes)

    # For inc state
    matchers =
      Map.values(~m(service_name lv_result))
      |> Enum.concat(tags)
      |> MapSet.new()

    {:noreply, inc_state(state, matchers)}
  end

  # Ignore successful calls from call event feed
  def handle_info(message = %{"lvResult" => "Operator Transfer" <> _}, state) do
    Db.insert_one("calls_raw", message)
    {:noreply, state}
  end

  # Unsuccessful calls from agent event feed
  def handle_info(message = %{"lvResult" => _something}, state) do
    Db.insert_one("calls_raw", message)

    underscored =
      Enum.map(message, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(
      client_id transaction_id session_id duration agent_login_id
      phone_dialed service_id lv_result
    ) = underscored

    agent_name = agent_login_id
    service_name = Livevox.ServiceInfo.name_of(service_id)
    lv_result = Livevox.Standardize.term_code(lv_result)

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
      |> Enum.concat(["lv_result:#{lv_result}"])

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
    client_name = Livevox.ClientInfo.get_client_name(service_name)
    caller_email = get_caller_email(service_name, agent_name)

    call =
      Map.merge(
        ~m(agent_name service_name duration phone_dialed lv_result caller_email),
        extra_attributes
      )

    # For inc state
    matchers =
      Map.values(~m(service_name lv_result))
      |> Enum.concat(tags)
      |> MapSet.new()

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

  def typey_downcase(val) when is_binary(val), do: String.downcase(val)
  def typey_downcase(val), do: val

  defp get_caller_email(service_name, agent_name) do
    client_name = Livevox.ClientInfo.get_client_name(service_name)
    do_get_caller_email(client_name, agent_name)
  end

  defp do_get_caller_email(client_name, ""), do: "unknown"
  defp do_get_caller_email(client_name, nil), do: "unknown"

  defp do_get_caller_email(client_name, agent_name) do
    %{body: body} = HTTPotion.get(login_management_url <> "/#{client_name}/#{agent_name}")

    case Poison.decode(body) do
      {:ok, %{"email" => email}} -> email
      _ -> "unknown"
    end
  end

  def unique_id(call) do
    timestamp = call["end"] || call["timestamp"]
    "#{call["phone_dialed"]}-#{timestamp}"
  end
end
