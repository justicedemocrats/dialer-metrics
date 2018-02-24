defmodule LivevoxWeb.Channel do
  use LivevoxWeb, :channel
  alias Phoenix.Socket.Broadcast
  import ShortMaps

  def join("live", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("status-for-service", ~m(service), socket) do
    status_breakdown = Livevox.Aggregators.AgentStatus.get_breakdown(%{"service_name" => service})
    push(socket, "breakdown", status_breakdown)
    {:noreply, socket}
  end

  def handle_in("get-throttle", ~m(service), socket) do
    ~m(throttle) = get_config(service)

    push(socket, "throttle", ~m(throttle))
    {:noreply, socket}
  end

  def handle_in("set-throttle", ~m(service value), socket) do
    ~m(throttle pacingMethod) = get_config(service)

    Livevox.Api.post(
      "configuration/v6.0/services/#{Livevox.ServiceInfo.id_of(service)}/pacing" |> IO.inspect(),
      body: %{
        method: pacingMethod,
        throttle: value
      }
    )

    ~m(throttle) = get_config(service)

    push(socket, "throttle", ~m(throttle))
    {:noreply, socket}
  end

  def get_config(service) do
    stats = Livevox.ServiceStatFeed.all_stats()

    stats
    |> Enum.filter(fn ~m(throttle serviceId pacingMethod) ->
      serviceId = Livevox.ServiceInfo.id_of(service)
    end)
    |> List.first()
  end
end
