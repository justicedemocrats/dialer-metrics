defmodule Livevox.Metrics.MonitorDropCounts do
  import ShortMaps

  @intervals ["today", 240, 120, 60, 30, 5, 1]
  @queries [
    %{"q" => %{}, "label" => "total"},
    %{"q" => %{"dialed" => true}, "label" => "dialed"},
    %{"q" => %{"dropped" => true}, "label" => "dropped"},
    %{"q" => %{"abandon" => true}, "label" => "abandon"},
    %{"q" => %{"voter_hangup" => true}, "label" => "voter_hangup"},
    %{"q" => %{"canvass" => true}, "label" => "canvass"},
    %{"q" => %{"contact" => true}, "label" => "contact"},
    %{"q" => %{"dnc_pass" => true}, "label" => "dnc"}
  ]

  def service_match(str), do: %{"$regex" => ".*#{str} Monitor.*", "$options" => "i"}

  def start_link do
    GenServer.start_link(
      __MODULE__,
      fn ->
        %{ready: %{}, not_ready: %{}, logged_on: %{}, in_call: %{}}
      end,
      name: __MODULE__
    )
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def report_over_period do
    service_names =
      Livevox.ServiceInfo.all_services()
      |> Flow.from_enumerable()
      |> Flow.map(&Livevox.ServiceInfo.name_of/1)
      |> Flow.reject(fn s ->
        String.contains?(s, "UNUSED") or String.contains?(s, "OLD") or String.contains?(s, "XXX")
      end)
      |> Flow.reject(fn s ->
        String.contains?(s, "Inbound")
      end)
      |> Flow.map(&String.replace(&1, "Callers", ""))
      |> Flow.map(&String.replace(&1, "Monitor", ""))
      |> Flow.map(&String.replace(&1, "QC", ""))
      |> Flow.map(&String.trim(&1))
      |> Enum.to_list()
      |> MapSet.new()
      |> Enum.to_list()

    service_names
    |> Flow.from_enumerable()
    |> Flow.flat_map(fn name ->
      starting = initial_count(name)

      Flow.from_enumerable(@queries)
      |> Flow.flat_map(fn query ->
        execute_service_query([], starting, @intervals, name, query)
      end)
      |> Enum.to_list()
    end)
    |> Enum.to_list()
    |> Dog.post_metrics()
  end

  def initial_count(service_name) do
    service_name = service_match(service_name)
    {:ok, count} = Db.count("calls", ~m(service_name))
    count
  end

  def execute_service_query(acc, _, [], _, _) do
    acc
  end

  def execute_service_query(acc, prev_count, [minutes_ago | remaining], service, ~m(q label)) do
    timestamp =
      case minutes_ago do
        "today" ->
          %{}

        n ->
          %{"timestamp" => %{"$gt" => Timex.shift(Timex.now(), minutes: -1 * n)}}
      end

    service_name = service

    count =
      case prev_count do
        0 ->
          0

        _n ->
          match = service_match(service_name)

          {:ok, count} =
            Db.count(
              "calls",
              q
              |> Map.merge(timestamp)
              |> Map.merge(%{"service_name" => match})
            )

          count
      end

    metric = "call_count_#{minutes_ago}"
    points = [[DateTime.to_unix(Timex.now(), :second), count]]
    tags = ["service_name:#{service}_monitor", label]
    type = "gauge"

    Enum.concat(acc, [~m(metric points tags type)])
    |> execute_service_query(count, remaining, service, ~m(q label))
  end
end
