defmodule Livevox.EventLoggers.ProcessCall do
  import ShortMaps

  def from_agent_halfway(call) do
    underscored =
      Enum.map(call, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(client_id transaction_id session_id agent_id
       phone_number call_service_id result) = underscored

    phone_dialed = phone_number

    service_name = Livevox.ServiceInfo.name_of(call_service_id)
    agent_name = Livevox.AgentInfo.name_of(agent_id)
    caller_attributes = Livevox.AgentInfo.get_caller_attributes(service_name, agent_name)

    lv_result =
      case Livevox.Standardize.term_code(result) do
        nil -> "operator transfer"
        "" -> "operator transfer"
        something -> something
      end

    extra_attributes = Livevox.AirtableCache.get_all() |> Map.get(lv_result)

    {:ok, timestamp} = DateTime.from_unix(underscored["timestamp"], :millisecond)
    id = unique_id(underscored)

    ~m(agent_name service_name phone_dialed lv_result id timestamp
       extra_attributes caller_attributes)
  end

  def from_agent_fully(call) do
    ~m(agent_name service_name phone_dialed lv_result id timestamp
       extra_attributes caller_attributes) = from_agent_halfway(call)

    ~m(agent_name service_name phone_dialed lv_result id timestamp)
    |> Map.merge(extra_attributes)
    |> Map.merge(caller_attributes)
  end

  def from_call_halfway(call) do
    underscored =
      Enum.map(call, fn {key, val} -> {Macro.underscore(key), typey_downcase(val)} end)
      |> Enum.into(%{})

    ~m(client_id transaction_id session_id duration agent_login_id
       phone_dialed service_id lv_result) = underscored

    agent_name = agent_login_id
    service_name = Livevox.ServiceInfo.name_of(service_id)
    id = unique_id(underscored)

    extra_attributes = Livevox.AirtableCache.get_all() |> Map.get(lv_result)

    {:ok, timestamp} = DateTime.from_unix(underscored["end"], :millisecond)

    ~m(id agent_name service_name phone_dialed lv_result id timestamp duration
       extra_attributes)
  end

  def unique_id(call) do
    timestamp = call["end"] || call["timestamp"]
    "#{call["phone_dialed"]}-#{timestamp}"
  end

  def typey_downcase(val) when is_binary(val), do: String.downcase(val)
  def typey_downcase(val), do: val

  def tagify(map) do
    map
    |> Enum.filter(fn
      {key, val} when is_boolean(val) -> val
      {key, val} -> val != ""
    end)
    |> Enum.map(fn
       {key, val} when is_boolean(val) -> key
       {key, val} -> "#{key}:#{val}"
     end)
  end
end
