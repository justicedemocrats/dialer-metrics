defmodule Livevox.ServiceStatFeed do
  alias Phoenix.PubSub
  import ShortMaps
  use Agent

  def start_link do
    Agent.start_link(fn -> get_all_cips() end, name: __MODULE__)
  end

  def update do
    %{body: ~m(stats)} = Livevox.Api.post("realtime/v6.0/service/stats", body: %{})
    timestamp = DateTime.utc_now()

    by_service = Enum.map(stats, fn s ->
      ~m(abandonRate callsWithAgent cip loaded longestCallInQueue pacingMethod
         percentComplete playingDialable remaining throttle totalAbandoned
         totalAgents totalHandled totalOffered serviceName) = s

      service_stats = %{
        abandon_rate: abandonRate,
        calls_with_agent: callsWithAgent,
        cip: cip,
        loaded: loaded,
        longest_call_in_queue: longestCallInQueue,
        pacing_method: pacingMethod,
        percent_complete: percentComplete,
        playing_dialable: playingDialable,
        remaining: remaining,
        throttle: throttle,
        total_abandoned: totalAbandoned,
        total_agents: totalAgents,
        total_handled: totalHandled,
        total_offered: totalOffered,
        service_name: serviceName,
        timestamp: timestamp
      }

      PubSub.broadcast!(:livevox, "service_stats", service_stats)
      {serviceName, stats}
    end)
    |> Enum.into(%{})

    Agent.update(__MODULE__, fn _ -> by_service end)
  end

  def all_stats do
    :sys.get_state(__MODULE__)
  end

  def stats_for(service_name) do
    :sys.get_state(__MODULE__)[service_name]
  end
end
