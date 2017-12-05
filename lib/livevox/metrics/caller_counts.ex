defmodule Livevox.Metrics.CallerCounts do
  alias Phoenix.{PubSub}
  alias Livevox.{ServiceInfo}
  use GenServer
  import ShortMaps

  @min_update_resolution 60_000 * 5

  def start_link do
    GenServer.start_link(
      __MODULE__,
      fn ->
        %{ready: %{}, not_ready: %{}, logged_on: %{}, in_call: %{}}
      end,
      name: __MODULE__
    )
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "agent_event")
    queue_update()
    {:ok, %{ready: %{}, not_ready: %{}, logged_on: %{}, in_call: %{}}}
  end

  def queue_update do
    spawn(fn ->
      :timer.sleep(@min_update_resolution)
      update()
    end)
  end

  def update do
    state = :sys.get_state(__MODULE__)

    ServiceInfo.all_services()
    |> Enum.each(fn sid -> post_all(state, sid) end)

    queue_update()
  end

  # -------------------------------------------------------------------------
  # -------------------------------- LOGON ----------------------------------
  # -------------------------------------------------------------------------
  def handle_info(message = %{"eventType" => "LOGON"}, state) do
    %{"agentId" => aid, "agentServiceId" => sid} = message

    new_state = Map.update!(state, :logged_on, &Map.put(&1, aid, sid))

    spawn(fn -> post_all(new_state, sid) end)
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

    spawn(fn -> post_all(new_state, sid) end)
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

    spawn(fn -> post_all(new_state, sid) end)
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

    spawn(fn -> post_all(new_state, sid) end)
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

    spawn(fn -> post_all(new_state, sid) end)
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

    spawn(fn -> post_all(new_state, sid) end)
    {:noreply, new_state}
  end

  def post_all(state, sid) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    series =
      Enum.map(~w(logged_on in_call ready not_ready)a, fn metric ->
        label = "count_#{Atom.to_string(metric)}"

        count =
          Map.get(state, metric)
          |> Enum.filter(fn {aid, other_sid} -> sid == other_sid end)
          |> length()

        %{
          metric: label,
          points: [[now, count]],
          tags: ["service:#{Livevox.ServiceInfo.name_of(sid)}"]
        }
      end)

    IO.inspect(series)
    Dog.post_metrics(series)
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
