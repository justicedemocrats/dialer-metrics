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

  def init(_opts) do
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{queued: %{}, to_ignore: MapSet.new()}}
  end

  # When they go not ready, queue a bunch of things to happen later
  def handle_info(message = %{"lineNumber" => "ACD", "eventType" => "NOT_READY"}, state) do
    service_name = Livevox.ServiceInfo.name_of(message["agentServiceId"])
    agent_name = Livevox.AgentInfo.name_of(message["agentId"])

    if service_name == "Dialer Monitor" do
      Logger.info("#{agent_name} is a dialer monitor. Ignoring.")
      {:noreply, state}
    else
      potentially_queued =
        if state.to_ignore |> MapSet.member?(agent_name) do
          Logger.info(
            "#{agent_name} has already demonstrated competence over the Ready / Not Ready functionality"
          )

          Livevox.MessageEngineConfig.get_all()
          |> Enum.filter(fn ~m(trigger_despite_competence) ->
            trigger_despite_competence == true
          end)
        else
          Livevox.MessageEngineConfig.get_all()
        end

      queued_actions =
        potentially_queued
        |> Enum.filter(&is_in_active_time_range/1)
        |> Enum.filter(fn ~m(service_regex) -> Regex.match?(service_regex, service_name) end)
        |> Enum.map(fn ~m(seconds_in_not_ready action message) ->
          {method, args} =
            case action do
              "message only" -> {:message, [agent_name, message]}
              "message and kick" -> {:message_and_kick, [agent_name, message]}
              "kick only" -> {:kick, [agent_name]}
              "force ready" -> {:force_ready, [agent_name]}
            end

          {:ok, timer_ref} =
            :timer.apply_after(:timer.seconds(seconds_in_not_ready), __MODULE__, method, args)

          timer_ref
        end)

      Logger.info("Queued #{length(queued_actions)} for #{agent_name}")

      {:noreply, put_in(state, [:queued, agent_name], queued_actions)}
    end
  end

  # When they go ready, they know whats up and should be ignored
  def handle_info(%{"lineNumber" => "ACD", "agentId" => agentId, "eventType" => "READY"}, state) do
    agent_name = Livevox.AgentInfo.name_of(agentId)

    cancellation_results =
      (state.queued[agent_name] || [])
      |> Enum.map(fn timer_ref -> :timer.cancel(timer_ref) end)

    Logger.info(
      "Cancelled #{length(cancellation_results)} messages for #{agent_name} because of READY"
    )

    new_queued = Map.drop(state.queued, [agent_name])
    to_ignore = state.to_ignore |> MapSet.put(agent_name)
    {:noreply, %{queued: new_queued, to_ignore: to_ignore}}
  end

  # When they do anything else, cancel all of the queues and drop them from state
  def handle_info(%{"lineNumber" => "ACD", "agentId" => agentId, "eventType" => et}, state) do
    agent_name = Livevox.AgentInfo.name_of(agentId)

    cancellation_results =
      (state.queued[agent_name] || [])
      |> Enum.map(fn timer_ref -> :timer.cancel(timer_ref) end)

    Logger.info(
      "Cancelled #{length(cancellation_results)} messages for #{agent_name} because of #{et}"
    )

    new_queued = Map.drop(state.queued, [agent_name])
    {:noreply, Map.put(state, :queued, new_queued)}
  end

  def handle_info(_message, state) do
    IO.puts("[messaging engine] unhandled message")
    {:noreply, state}
  end

  def handle_cast({:cancel, agent_name}, state) do
    cancellation_results =
      (state.queued[agent_name] || [])
      |> Enum.map(fn timer_ref -> :timer.cancel(timer_ref) end)

    Logger.info(
      "Cancelled #{length(cancellation_results)} messages for #{agent_name} because of internal force"
    )

    new_queued = Map.drop(state.queued, [agent_name])
    {:noreply, Map.put(state, :queued, new_queued)}
  end

  def is_in_active_time_range(~m(active_time_range)) do
    [{start_hours, _}, {end_hours, _}] =
      String.split(active_time_range, "-") |> Enum.map(&Integer.parse/1)

    now_est_hours = Timex.now("America/New_York").hour
    now_est_hours >= start_hours and now_est_hours < end_hours
  end

  def kick(agent) do
    Logger.info("[message engine] Kicking #{agent}")

    Livevox.Api.post(
      "callControl/supervisor/agent/status/logoff",
      body: %{
        "agents" => [agent]
      }
    )
  end

  def kick_with_message(agent, message) do
    Logger.info("[message engine] Kicking #{agent} with message #{message}")

    Livevox.Api.post(
      "callControl/supervisor/agent/status/logoff",
      body: %{
        "agents" => [agent],
        "message" => message
      }
    )
  end

  def message(agent, message) do
    Logger.info("[message engine] Messaging #{agent} with message #{message}")

    Livevox.Api.post(
      "callControl/supervisor/chat/send",
      body: %{
        "userLoginId" => agent,
        "message" => message
      }
    )
  end

  def force_ready(agent) do
    Logger.info("[message engine] Forcing #{agent} ready")

    resp =
      Livevox.Api.post(
        "callControl/supervisor/agent/status/ready",
        body: %{"agents" => [agent]}
      )

    case List.first(resp.body["agents"]) |> Map.get("status") do
      # forced ready
      "Success" ->
        GenServer.cast(__MODULE__, {:cancel, agent})

      # already ready
      "Invalid Agent state" ->
        GenServer.cast(__MODULE__, {:cancel, agent})

      # failure
      _ ->
        IO.puts("#{agent} has not connected yet. Cannot force ready, will try again.")
    end
  end
end
