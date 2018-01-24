defmodule LivevoxWeb.AgentsChannel do
  use LivevoxWeb, :channel
  alias Phoenix.Socket.Broadcast
  import ShortMaps

  def join("agent-status", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("status-for-service", ~m(service), socket) do
    status_breakdown = Livevox.Aggregators.AgentStatus.get_breakdown(%{"service_name" => service})
    push(socket, "breakdown", status_breakdown)
    {:noreply, socket}
  end
end
