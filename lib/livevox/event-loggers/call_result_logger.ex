defmodule Livevox.EventLoggers.CallResult do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  @flush_resolution 30_000
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

  # Successful calls from agent event feed
  def handle_info(
        message = %{"lineNumber" => "ACD", "eventType" => "WRAP_UP", "result" => _},
        state
      ) do
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

    # For mongo
    client_name = Livevox.ClientInfo.get_client_name(service_name)
    caller_email = get_caller_email(service_name, agent_name)

    call =
      Map.merge(~m(agent_name service_name phone_dialed lv_result caller_email), extra_attributes)

    {:ok, timestamp} = DateTime.from_unix(underscored["timestamp"], :millisecond)
    id = unique_id(underscored)
    Db.update("calls", %{"id" => id}, Map.merge(call, ~m(timestamp)))

    {:noreply, %{}}
  end

  # Unsuccessful calls from agent event feed
  def handle_info(message = %{"lvResult" => _something}, state) do
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

    # For mongo
    client_name = Livevox.ClientInfo.get_client_name(service_name)
    caller_email = get_caller_email(service_name, agent_name)

    call =
      Map.merge(
        ~m(agent_name service_name duration phone_dialed lv_result caller_email),
        extra_attributes
      )

    {:ok, timestamp} = DateTime.from_unix(underscored["timestamp"], :millisecond)
    id = unique_id(underscored)
    Db.update("calls", %{"id" => id}, Map.merge(call, ~m(timestamp)))

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

  def handle_info(_, _) do
    {:noreply, %{}}
  end

  def unique_id(call) do
    timestamp = call["end"] || call["timestamp"]
    "#{call["phone_dialed"]}-#{timestamp}"
  end
end
