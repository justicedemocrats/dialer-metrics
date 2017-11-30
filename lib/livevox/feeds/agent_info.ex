defmodule Livevox.AgentInfo do
  use Agent
  @ttl 60_000

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def name_of(agent_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.get(state, agent_id) do
        nil ->
          %{body: %{"loginId" => name}} = Livevox.Api.get("configuration/v6.0/agents/#{agent_id}")

          # Invalidate in ttl
          spawn(fn ->
            :timer.sleep(@ttl)
            clear_cache_of(agent_id)
          end)

          {name, Map.put(state, agent_id, name)}

        name ->
          {name, state}
      end
    end)
  end

  def clear_cache_of(agent_id) do
    Agent.update(__MODULE__, fn state ->
      Map.drop(state, [agent_id])
    end)
  end
end
