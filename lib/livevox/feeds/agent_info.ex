defmodule Livevox.AgentInfo do
  import ShortMaps
  use Agent
  @ttl 60_000
  def login_management_url, do: Application.get_env(:livevox, :login_management_url)

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

  def get_caller_attributes(service_name, agent_name) do
    client_name = Livevox.ClientInfo.get_client_name(service_name)
    do_get_caller_attributes(client_name, agent_name)
  end

  defp do_get_caller_attributes(client_name, ""), do: nil
  defp do_get_caller_attributes(client_name, nil), do: nil

  defp do_get_caller_attributes(client_name, agent_name) do
    %{body: body} = HTTPotion.get(login_management_url <> "/#{client_name}/#{agent_name}")

    case Poison.decode(body) do
      {:ok, %{"email" => caller_email, "calling_from" => calling_from}} ->
        ~m(caller_email calling_from)

      _ ->
        %{}
    end
  end
end
