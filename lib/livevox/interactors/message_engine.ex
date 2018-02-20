defmodule Livevox.Interactors.MessageEngine do
  use GenServer
  import ShortMaps
  alias Phoenix.{PubSub}
  require Logger

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

  # When they go not ready, queue a bunch of things to happen later
  def handle_info(message = %{"lineNumber" => "ACD", "eventType" => "NOT_READY"}, state) do
    service_name = Livevox.ServiceInfo.name_of(message["agentServiceId"])
    agent_name = Livevox.AgentInfo.name_of(message["agentId"])

    queued_actions =
      Livevox.MessageEngineConfig.get_all()
      |> Enum.filter(&is_in_active_time_range/1)
      |> Enum.filter(fn ~m(service_regex) -> Regex.match?(service_regex, service_name) end)
      |> Enum.map(fn ~m(seconds_in_not_ready reference_name action message) ->
        {method, args} =
          case action do
            "message only" -> {:message, [agent_name, message]}
            "message and kick" -> {:message_and_kick, [agent_name, message]}
            "kick only" -> {:kick, [agent_name]}
          end

        {:ok, timer_ref} =
          :timer.apply_after(:timer.seconds(seconds_in_not_ready), __MODULE__, method, args)

        timer_ref
      end)

    {:noreply, Map.put(state, agent_name, queued_actions)}
  end

  # When they do anything else, cancel all of the queues and drop them from state
  def handle_info(%{"agentId" => agentId}, state) do
    agent_name = Livevox.AgentInfo.name_of(agentId)

    (state[agent_name] || [])
    |> Enum.map(fn timer_ref -> :timer.cancel(timer_ref) end)

    {:noreply, Map.drop(state, [agent_name])}
  end

  def handle_info(message, state) do
    IO.puts("[messaging engine] unhandled message")
    IO.inspect(message)
    {:noreply, state}
  end

  def is_in_active_time_range(~m(active_time_range)) do
    [{start_hours, _}, {end_hours, _}] =
      String.split(active_time_range, "-") |> Enum.map(&Integer.parse/1)

    now_est_hours = Timex.now("America/New_York").hour
    now_est_hours >= start_hours and now_est_hours < end_hours
  end

  # https://docs.livevox.com/display/DP/Call+Control+API+v6.0+-+REST#CallControlAPIv6.0-REST-LogoffAgents
  def kick(agent) do
    Logger.info("[message engine] Kicking #{agent}")

    Livevox.Api.post(
      "callControl/v6.0/supervisor/agent/status/logoff",
      body: %{
        "agents" => [agent]
      }
    )
  end

  def kick_with_message(agent, message) do
    Logger.info("[message engine] Kicking #{agent} with message #{message}")

    Livevox.Api.post(
      "callControl/v6.0/supervisor/agent/status/logoff",
      body: %{
        "agents" => [agent],
        "message" => message
      }
    )
  end

  # https://docs.livevox.com/display/DP/Call+Control+API+v6.0+-+REST#CallControlAPIv6.0-REST-SendChatMessage.1
  def message(agent, message) do
    Logger.info("[message engine] Messaging #{agent} with message #{message}")

    Livevox.Api.post(
      "callControl/v6.0/supervisor/chat/send",
      body: %{
        "userLoginId" => agent,
        "message" => message
      }
    )
  end
end
