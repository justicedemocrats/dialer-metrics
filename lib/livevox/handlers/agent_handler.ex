defmodule Livevox.AgentHandler do
  use Livevox.AgentEventFeed

  def handle_agent_event(agent_event) do
    Livevox.AgentState.handle_agent_event(agent_event)
    # Livevox.ServiceState.handle_agent_event(agent_event)
  end
end
