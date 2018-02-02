defmodule Livevox.Metrics.CallerCounts do
  alias Phoenix.{PubSub}
  alias Livevox.{ServiceInfo}
  use GenServer
  import ShortMaps

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
    {:ok, %{ready: %{}, not_ready: %{}, logged_on: %{}, in_call: %{}}}
  end

  def update do
    state = :sys.get_state(__MODULE__)

    ServiceInfo.all_services()
    |> Enum.each(fn sid -> post_all(state, sid) end)
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

    get_count_in_state = fn key ->
      Map.get(state, key)
      |> Enum.filter(fn {aid, other_sid} -> sid == other_sid end)
      |> length()
    end

    counts =
      ~w(logged_on in_call ready not_ready)a
      |> Enum.map(fn metric ->
        {metric, get_count_in_state.(metric)}
      end)
      |> Enum.into(%{})

    tags = ["service:#{Livevox.ServiceInfo.name_of(sid)}"]

    series =
      Enum.map(~w(logged_on in_call ready not_ready)a, fn metric ->
        label = "count_#{Atom.to_string(metric)}"
        count = counts[metric]

        %{
          metric: label,
          points: [[now, count]],
          tags: tags
        }
      end)
      |> Enum.concat([
        %{
          metric: "count_active",
          points: [[now, counts.logged_on - counts.not_ready]],
          tags: tags
        }
      ])

    Dog.post_metrics(series)
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
