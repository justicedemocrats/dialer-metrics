defmodule Livevox.AgentInfo do
  import ShortMaps
  use Agent
  @ttl 60_000 * 60
  def login_management_url, do: Application.get_env(:livevox, :login_management_url)

  def start_link do
    Agent.start_link(fn -> %{ids_to_logins: %{}, logins_to_info: %{}} end, name: __MODULE__)
  end

  def name_of(agent_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case get_in(state, [:ids_to_logins, "agent_id"]) do
        nil ->
          %{body: %{"loginId" => name}} = Livevox.Api.get("configuration/v6.0/agents/#{agent_id}")

          # Invalidate in ttl
          spawn(fn ->
            :timer.sleep(@ttl)
            clear_cache_of([:ids_to_logins, agent_id])
          end)

          {name, put_in(state, [:ids_to_logins, agent_id], name)}

        name ->
          {name, state}
      end
    end)
  end

  def clear_cache_of(key_list) do
    Agent.update(__MODULE__, fn state ->
      put_in(state, key_list, nil)
    end)
  end

  def get_caller_attributes(service_name, agent_name) do
    key_set = [:logins_to_info, MapSet.new([service_name, agent_name])]

    Agent.get_and_update(__MODULE__, fn state ->
      case get_in(state, key_set) do
        nil ->
          client_name = Livevox.ClientInfo.get_client_name(service_name)
          attributes = do_get_caller_attributes(client_name, agent_name)

          # Invalidate in ttl
          spawn(fn ->
            :timer.sleep(@ttl)
            clear_cache_of(key_set)
          end)

          {
            attributes,
            put_in(state, key_set, attributes)
          }

        caller_attributes = %{} ->
          {caller_attributes, state}
      end
    end)
  end

  defp do_get_caller_attributes(client_name, ""), do: nil
  defp do_get_caller_attributes(client_name, nil), do: nil

  defp do_get_caller_attributes(client_name, agent_name) do
    %{body: body} = HTTPotion.get(login_management_url <> "/#{client_name}/#{agent_name}")

    case Poison.decode(body) do
      {:ok, %{"email" => caller_email, "calling_from" => calling_from, "phone" => phone}} ->
        ~m(caller_email calling_from phone)

      _ ->
        %{}
    end
  end
end
