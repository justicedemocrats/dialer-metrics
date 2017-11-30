defmodule Livevox.ServiceFeed do
  alias Phoenix.PubSub
  import ShortMaps

  @resolution 10_000

  def start_link do
    Task.start_link(fn -> get_all_cips() end)
  end

  def get_all_cips do
    %{body: ~m(stats)} = Livevox.Api.post("realtime/v6.0/service/stats", body: %{})
    timestamp = DateTime.utc_now()

    Enum.each(stats, fn ~m(cip serviceName throttle playingDialable percentComplete) ->
      PubSub.broadcast!(:livevox, "service_cip", %{
        cip: cip,
        service_name: serviceName,
        playing_dialable: playingDialable,
        percent_complete: percentComplete,
        throttle: throttle,
        timestamp: timestamp
      })
    end)

    IO.inspect("Fetched and broadcast new")

    :timer.sleep(@resolution)
    get_all_cips()
  end

  # def get_all_services do
  #   %{body: ~m(stats)} = Livevox.Api.post("realtime/v6.0/service/stats", body: %{})
  #
  #   centers
  #   |> Enum.map(fn %{"callCenterId" => cid} -> cid end)
  #   |> Enum.flat_map(fn cid ->
  #        %{body: %{"service" => services}} =
  #          Livevox.Api.get("configuration/v6.0/services", query: %{
  #            callCenter: cid,
  #            count: 1000,
  #            offset: 0
  #          })
  #
  #        services
  #      end)
  #   |> Enum.filter(&(Map.get(&1, "name") |> String.contains?("QC")))
  # end
end
