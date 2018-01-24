defmodule Livevox.Aggregators.AgentStatus do
  alias Phoenix.{PubSub}
  alias Livevox.{ServiceInfo, AgentInfo}
  use GenServer
  import ShortMaps

  @min_update_resolution 60_000 * 5

  def start_link do
    GenServer.start_link(
      __MODULE__,
      fn ->
        %{ready: %{}, not_ready: %{}, logged_on: %{}, in_call: %{}, wrap_up: %{}}
      end,
      name: __MODULE__
    )
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{ready: %{}, not_ready: %{}, logged_on: %{}, in_call: %{}, wrap_up: %{}}}
  end

  # -------------------------------------------------------------------------
  # -------------------------------- LOGON ----------------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => "LOGON"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message
    new_state = Map.update!(state, :logged_on, &Map.put(&1, aid, sid))
    {:noreply, new_state}
  end

  # -------------------------------------------------------------------------
  # -------------------------------- READY ----------------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => "READY", "lineNumber" => "ACD"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message

    new_state =
      state
      |> Map.update!(:ready, &Map.put(&1, aid, sid))
      |> Map.update!(:logged_on, &Map.put(&1, aid, sid))
      |> Map.update!(:not_ready, &Map.drop(&1, [aid]))
      |> Map.update!(:in_call, &Map.drop(&1, [aid]))
      |> Map.update!(:wrap_up, &Map.drop(&1, [aid]))

    {:noreply, new_state}
  end

  # -------------------------------------------------------------------------
  # ---------------------------- NOT READY ----------------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => "NOT_READY", "lineNumber" => "ACD"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message

    new_state =
      state
      |> Map.update!(:not_ready, &Map.put(&1, aid, sid))
      |> Map.update!(:logged_on, &Map.put(&1, aid, sid))
      |> Map.update!(:ready, &Map.drop(&1, [aid]))
      |> Map.update!(:in_call, &Map.drop(&1, [aid]))
      |> Map.update!(:wrap_up, &Map.drop(&1, [aid]))

    {:noreply, new_state}
  end

  # -------------------------------------------------------------------------
  # ---------------------------- IN CALL ------------------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => "IN_CALL", "lineNumber" => "ACD"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message

    new_state =
      state
      |> Map.update!(:in_call, &Map.put(&1, aid, sid))
      |> Map.update!(:logged_on, &Map.put(&1, aid, sid))
      |> Map.update!(:ready, &Map.drop(&1, [aid]))
      |> Map.update!(:not_ready, &Map.drop(&1, [aid]))
      |> Map.update!(:wrap_up, &Map.drop(&1, [aid]))

    {:noreply, new_state}
  end

  # -------------------------------------------------------------------------
  # ---------------------------- WRAP UP ------------------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => "WRAP_UP", "lineNumber" => "ACD"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message

    new_state =
      state
      |> Map.update!(:wrap_up, &Map.put(&1, aid, sid))
      |> Map.update!(:logged_on, &Map.put(&1, aid, sid))
      |> Map.update!(:ready, &Map.drop(&1, [aid]))
      |> Map.update!(:not_ready, &Map.drop(&1, [aid]))
      |> Map.update!(:in_call, &Map.drop(&1, [aid]))

    {:noreply, new_state}
  end

  # -------------------------------------------------------------------------
  # ---------------------------- OTHER ACD EVENT ----------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => _unknown, "lineNumber" => "ACD"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message

    new_state =
      state
      |> Map.update!(:logged_on, &Map.put(&1, aid, sid))
      |> Map.update!(:in_call, &Map.drop(&1, [aid]))
      |> Map.update!(:ready, &Map.drop(&1, [aid]))
      |> Map.update!(:not_ready, &Map.drop(&1, [aid]))
      |> Map.update!(:wrap_up, &Map.drop(&1, [aid]))

    {:noreply, new_state}
  end

  # -------------------------------------------------------------------------
  # ---------------------------- LOG OFF ------------------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => "LOGOFF"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message

    new_state =
      state
      |> Map.update!(:logged_on, &Map.drop(&1, [aid]))
      |> Map.update!(:in_call, &Map.drop(&1, [aid]))
      |> Map.update!(:ready, &Map.drop(&1, [aid]))
      |> Map.update!(:not_ready, &Map.drop(&1, [aid]))

    {:noreply, new_state}
  end

  def get_breakdown(~m(service_name sid)) do
    state = :sys.get_state(__MODULE__)

    stats =
      Enum.map(~w(in_call ready not_ready wrap_up)a, fn metric ->
        aids =
          Map.get(state, metric)
          |> Enum.filter(fn {aid, other_sid} -> sid == other_sid end)
          |> Enum.map(fn {aid, _} -> aid end)

        {metric, service_name, aids}
      end)
      |> Enum.map(&fill_info/1)
      |> Enum.map(&Task.await/1)
      |> Enum.into(%{})
  end

  def get_breakdown(~m(service_name)) do
    sid = ServiceInfo.id_of(service_name)
    get_breakdown(~m(service_name sid))
  end

  def get_breakdown(sid) do
    service_name = ServiceInfo.name_of(sid)
    get_breakdown(~m(service_name sid))
  end

  defp fill_info({metric, service_name, aids}) when is_list(aids) do
    Task.async(fn ->
      with_info =
        aids
        |> Enum.map(fn aid -> fill_info(service_name, aid) end)
        |> Enum.map(&Task.await/1)

      {metric, with_info}
    end)
  end

  defp fill_info(service_name, aid) do
    Task.async(fn ->
      login = AgentInfo.name_of(aid)
      other_attrs = AgentInfo.get_caller_attributes(service_name, login)
      Map.merge(other_attrs, ~m(login))
    end)
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
