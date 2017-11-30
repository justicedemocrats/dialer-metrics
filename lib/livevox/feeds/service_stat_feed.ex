defmodule Livevox.ServiceStatFeed do
  alias Phoenix.PubSub
  import ShortMaps

  @resolution 10_000

  def start_link do
    Task.start_link(fn -> get_all_cips() end)
  end

  def get_all_cips do
    %{body: ~m(stats)} = Livevox.Api.post("realtime/v6.0/service/stats", body: %{})
    timestamp = DateTime.utc_now()

    Enum.each(
      stats,
      fn ~m(abandonRate callsWithAgent cip loaded longestCallInQueue pacingMethod percentComplete playingDialable remaining throttle totalAbandoned totalAgents totalHandled totalOffered serviceName) ->
        PubSub.broadcast!(:livevox, "service_stats", %{
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
        })
      end
    )

    :timer.sleep(@resolution)
    get_all_cips()
  end
end
