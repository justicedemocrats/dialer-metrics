defmodule Livevox.Aggregators.AgentStatus do
  alias Phoenix.{PubSub}
  alias Livevox.{ServiceInfo, AgentInfo}
  use Agent
  import ShortMaps

  @status_map %{
    "0" => [],
    "1" => ~w(logged_on)a,
    "2" => ~w(logged_on ready active)a,
    "3" => ~w(logged_on not_ready)a,
    "4" => ~w(logged_on in_call active)a,
    "5" => ~w(logged_on wrap_up active)a
  }

  @initial_state %{
    ready: %{},
    not_ready: %{},
    logged_on: %{},
    in_call: %{},
    wrap_up: %{},
    active: %{}
  }

  def start_link do
    Agent.start_link(
      fn ->
        @initial_state
      end,
      name: __MODULE__
    )
  end

  def update do
    %{body: ~m(agentDetails)} = Livevox.Api.post("realtime/service/agents/status", body: %{})

    reducer = fn ~m(serviceId agentLoginId stateId), acc ->
      statuses = @status_map["#{stateId}"]

      Enum.reduce(statuses, acc, fn status, deep_acc ->
        put_in(deep_acc, [status, agentLoginId], serviceId)
      end)
    end

    state = Enum.reduce(agentDetails, @initial_state, reducer)
    Agent.update(__MODULE__, fn _ -> state end)
    spawn(fn -> post_metrics(state) end)
    :ok
  end

  def get_breakdown(~m(service_name sid)) do
    state = :sys.get_state(__MODULE__)

    Enum.map(~w(in_call ready not_ready wrap_up active)a, fn metric ->
      logins =
        Map.get(state, metric)
        |> Enum.filter(fn {_aid, other_sid} -> sid == other_sid end)
        |> Enum.map(fn {login, _} -> login end)

      {metric, service_name, logins}
    end)
    |> Enum.map(&fill_info/1)
    |> Enum.map(fn t -> Task.await(t, 100_000) end)
    |> Enum.into(%{})
  end

  def get_breakdown(~m(service_name)) do
    sid = ServiceInfo.id_of(service_name)
    real_service_name = ServiceInfo.name_of(sid)

    ~m(sid)
    |> Map.put("service_name", real_service_name)
    |> get_breakdown()
  end

  def get_breakdown(sid) do
    service_name = ServiceInfo.name_of(sid)
    get_breakdown(~m(service_name sid))
  end

  defp fill_info({metric, service_name, logins}) when is_list(logins) do
    Task.async(fn ->
      with_info =
        logins
        |> Enum.map(fn login -> fill_info(service_name, login) end)
        |> Enum.map(fn t -> Task.await(t, 100_000) end)

      {metric, with_info}
    end)
  end

  defp fill_info(service_name, login) do
    Task.async(fn ->
      other_attrs = AgentInfo.get_caller_attributes(service_name, login)
      Map.merge(other_attrs, ~m(login))
    end)
  end

  defp post_metrics(state) do
    ServiceInfo.all_services()
    |> Enum.each(fn sid ->
      now = DateTime.utc_now() |> DateTime.to_unix()

      get_count_in_state = fn key ->
        Map.get(state, key)
        |> Enum.filter(fn {_aid, other_sid} -> sid == other_sid end)
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
        Enum.map(~w(logged_on in_call ready not_ready active)a, fn metric ->
          label = "count_#{Atom.to_string(metric)}"
          count = counts[metric]

          %{
            metric: label,
            points: [[now, count]],
            tags: tags
          }
        end)

      Dog.post_metrics(series)
    end)
  end
end
