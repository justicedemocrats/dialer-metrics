defmodule Livevox.Metrics.CallCounts do
  import ShortMaps

  @regexify fn str -> %{"$regex" => ".*#{str}.*", "$options" => "i"} end

  @intervals ["today", 240, 120, 60, 30, 5, 1]
  @queries [
    %{"q" => %{}, "label" => "total"},
    %{"q" => %{"dialed" => true}, "label" => "dialed"},
    %{"q" => %{"dropped" => true}, "label" => "dropped"},
    %{"q" => %{"abandon" => true}, "label" => "abandon"},
    %{"q" => %{"voter_hangup" => true}, "label" => "voter_hangup"},
    %{"q" => %{"canvass" => true}, "label" => "canvass"},
    %{"q" => %{"contact" => true}, "label" => "contact"},
    %{"q" => %{"dnc_pass" => true}, "label" => "dnc"},
    %{"q" => %{"van_result" => "Wrong Number"}, "label" => "van_result:wrong_number"},
    %{
      "q" => %{"van_result" => @regexify.("strong support")},
      "label" => "van_result:strong_support"
    },
    %{"q" => %{"van_result" => @regexify.("lean support")}, "label" => "van_result:lean_support"},
    %{"q" => %{"van_result" => @regexify.("undecided")}, "label" => "van_result:undecided"},
    %{
      "q" => %{"van_result" => @regexify.("lean opponent")},
      "label" => "van_result:lean_opponent"
    },
    %{
      "q" => %{"van_result" => @regexify.("strong opponent")},
      "label" => "van_result:strong_opponent"
    },
    %{"q" => %{"van_result" => @regexify.("lean other")}, "label" => "van_result:lean_other"},
    %{"q" => %{"van_result" => @regexify.("strong other")}, "label" => "van_result:strong_other"},
    %{"q" => %{"van_result" => @regexify.("not voting")}, "label" => "van_result:not_voting"},
    %{"q" => %{"e_day" => @regexify.("will vote")}, "label" => "e_day:will_vote"},
    %{"q" => %{"e_day" => @regexify.("already voted")}, "label" => "e_day:already_voted"},
    %{"q" => %{"e_day" => @regexify.("not_voting")}, "label" => "e_day:not_voting"}
  ]

  def service_match(str), do: %{"$regex" => ".*#{str} [CMQ].*", "$options" => "i"}

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
    time_after = Timex.shift(Timex.now(), minutes: -240)
    timestamp = %{"$gt" => time_after}
    service_name = service_match(service_name)
    {:ok, count} = Db.count("calls", ~m(service_name timestamp))
    count
  end

  def execute_service_query(acc, _, [], _, _) do
    acc
  end

  def execute_service_query(acc, prev_count, [minutes_ago | remaining], service, ~m(q label)) do
    time_after =
      case minutes_ago do
        "today" -> Timex.now("America/New_York") |> Timex.set(hour: 0, minute: 0, second: 0)
        n -> Timex.shift(Timex.now(), minutes: -1 * n)
      end

    timestamp = %{"$gt" => time_after}
    service_name = service

    count =
      case prev_count do
        0 ->
          0

        _n ->
          match = service_match(service_name)

          {:ok, count} =
            Db.count("calls", Map.merge(q, %{"service_name" => match, "timestamp" => timestamp}))

          count
      end

    metric = "call_count_#{minutes_ago}"
    points = [[DateTime.to_unix(Timex.now(), :second), count]]
    tags = ["service_name:#{service}", label]
    type = "gauge"

    Enum.concat(acc, [~m(metric points tags type)])
    |> execute_service_query(count, remaining, service, ~m(q label))
  end
end
