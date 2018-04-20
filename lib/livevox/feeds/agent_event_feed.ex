defmodule Livevox.AgentEventFeed do
  alias Phoenix.PubSub

  def start_link do
    Task.start_link(fn -> get_activity() end)
  end

  def get_activity do
    resp =
      %{body: %{"token" => token}} =
      Livevox.Api.post("realtime/agentEvent/feed", body: %{}, timeout: 20_000)

    handle_events(resp.body["agentEvent"])

    get_activity(token)
  end

  def get_activity(token) do
    resp =
      %{body: %{"token" => new_token}} =
      Livevox.Api.post(
        "realtime/agentEvent/feed",
        body: %{token: token},
        timeout: 20_000
      )
      |> IO.inspect()

    handle_events(resp.body["agentEvent"])

    get_activity(new_token)
  end

  defp handle_events(events) do
    events
    |> Enum.sort_by(& &1["timestamp"], &<=/2)
    |> Enum.each(fn ev ->
      PubSub.broadcast(:livevox, "agent_event", ev)
    end)
  end
end
