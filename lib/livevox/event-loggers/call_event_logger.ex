defmodule Livevox.EventLoggers.CallEvent do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn ->
      %{}
    end)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "call_event")
    {:ok, %{}}
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
      |> IO.inspect()

    lv_result = agent_result["lv_result"] || underscored["lv_result"]

    extra_attributes = Livevox.AirtableCache.get_all() |> Map.get(lv_result)

    IO.inspect(underscored)
    IO.inspect(lv_result)
    IO.inspect(extra_attributes)

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

    Dog.post_event(%{
      title: "call",
      date_happened: timestamp,
      tags: tags
    })

    call =
      Map.merge(~m(agent_name service_name duration phone_dialed lv_result), extra_attributes)

    Mongo.insert_one(:mongo, "calls", call)

    {:noreply, %{}}
  end

  def handle_info(_, _) do
    {:noreply, %{}}
  end

  defp get_agent_result(session_id, transaction_id, client_id) do
    %{body: body} =
      Livevox.Api.get("realtime/v5.0/callData/postCall", query: %{
        clientId: client_id,
        transaction: transaction_id,
        session: session_id
      })

    body
  end

  defp typey_downcase(val) when is_binary(val), do: String.downcase(val)
  defp typey_downcase(val), do: val
end
