defmodule Livevox.Metrics.CallerCounts do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn ->
      %{ready: [], not_ready: [], logged_on: [], in_call: []}
    end)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{}}
  end

  def handle_info(message = %{"eventType" => "LOGON"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => service_id} = message

    new_logged_on =
      Map.get(state, :logged_on)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)
      |> Enum.concat([{agent_id, service_id}])

    post_all(state, :logged_on)

    {:noreply, Map.put(state, :logged_on, new_logged_on)}
  end

  def handle_info(message = %{"eventType" => "READY"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => service_id} = message

    new_ready =
      Map.get(state, :ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)
      |> Enum.concat([{agent_id, service_id}])

    new_not_ready =
      Map.get(state, :ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_state =
      state
      |> Map.put(:ready, new_ready)
      |> Map.put(:not_ready, new_not_ready)

    post_all(new_state, :ready)
    post_all(new_state, :not_ready)

    {:noreply, Map.put(state, :ready, new_ready)}
  end

  def handle_info(message = %{"eventType" => "NOT_READY"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => service_id} = message

    new_ready =
      Map.get(state, :ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_not_ready =
      Map.get(state, :not_ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_state =
      state
      |> Map.put(:ready, new_ready)
      |> Map.put(:not_ready, new_not_ready)

    post_all(new_state, :ready)
    post_all(new_state, :not_ready)

    {:noreply, Map.put(state, :not_ready, new_ready)}
  end

  def handle_info(message = %{"eventType" => "IN_CALL"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => service_id} = message

    new_ready =
      Map.get(state, :ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_in_call =
      Map.get(state, :in_call)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)
      |> Enum.concat([{agent_id, service_id}])

    new_state =
      state
      |> Map.put(:ready, new_ready)
      |> Map.put(:in_call, new_in_call)

    post_all(new_state, :ready)
    post_all(new_state, :in_call)

    {:noreply, Map.put(state, :not_ready, new_ready)}
  end

  def handle_info(message = %{"eventType" => _unknown}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => service_id} = message

    new_ready =
      Map.get(state, :ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_state =
      state
      |> Map.put(:ready, new_ready)

    post_all(new_state, :ready)

    {:noreply, Map.put(state, :not_ready, new_ready)}
  end

  def handle_info(message = %{"eventType" => "LOGOFF"}, state) do
    %{"agentId" => agent_id, "timestamp" => timestamp, "agentServiceId" => service_id} = message

    new_ready =
      Map.get(state, :ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_not_ready =
      Map.get(state, :not_ready)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_logged_on =
      Map.get(state, :logged_on)
      |> Enum.filter(fn {aid, sid} -> aid != aid end)

    new_state =
      state
      |> Map.put(:ready, new_ready)
      |> Map.put(:not_ready, new_not_ready)
      |> Map.put(:logged_on, new_logged_on)

    post_all(new_state, :ready)
    post_all(new_state, :not_ready)
    post_all(new_state, :logged_ready)

    {:noreply, Map.put(state, :not_ready, new_ready)}
  end

  def post_all(state, metric) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    metric = "callers_#{Atom.to_string(metric)}"
    total = %{metric: metric, points: [[now, length(state[metric])]], tags: []}

    service_level =
      state[metric]
      |> Enum.reduce(%{}, fn {aid, sid}, acc ->
           Map.get_and_update(acc, sid, &(&1 + 1))
         end)
      |> Enum.map(fn {sid, count} ->
           %{metric: metric, points: [[now, count]], tags: [Livevox.ServiceInfo.name_of(sid)]}
         end)

    series = [total | service_level]
    Dog.post_metrics(series)
  end
end
