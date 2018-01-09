defmodule Livevox.Metrics.CallCounts do
  import ShortMaps

  @regexify fn str -> %{"$regex" => ".*#{str}.*", "$options" => "i"} end

  @run_every 60_000
  @intervals [1, 5, 30, 60, 120, 240]
  @queries [
    %{"q" => %{}, "label" => "total"},
    %{"q" => %{"dialed" => true}, "label" => "dialed"},
    %{"q" => %{"dropped" => true}, "label" => "dropped"},
    %{"q" => %{"abandon" => true}, "label" => "abandon"},
    %{"q" => %{"voter_hangup" => true}, "label" => "voter_hangup"},
    %{"q" => %{"canvass" => true}, "label" => "canvass"},
    %{"q" => %{"contact" => true}, "label" => "contact"},
    %{"q" => %{"dnc_pass" => true}, "label" => "dnc"},
    %{"q" => %{"van_result" => "Wrong Number"}, "label" => "van_wrong_number"},
    %{"q" => %{"van_result" => @regexify.("strong support")}, "label" => "van_strong_support"},
    %{"q" => %{"van_result" => @regexify.("lean support")}, "label" => "van_lean_support"},
    %{"q" => %{"van_result" => @regexify.("undecided")}, "label" => "van_undecided"},
    %{"q" => %{"van_result" => @regexify.("lean opponent")}, "label" => "van_lean_opponent"},
    %{"q" => %{"van_result" => @regexify.("strong opponent")}, "label" => "van_strong_opponent"},
    %{"q" => %{"van_result" => @regexify.("lean other")}, "label" => "van_lean_other"},
    %{"q" => %{"van_result" => @regexify.("strong other")}, "label" => "van_strong_other"},
    %{"q" => %{"van_result" => @regexify.("not voting")}, "label" => "van_not_voting"},
    %{"q" => %{"e_day" => @regexify.("will vote")}, "label" => "e_day_will_vote"},
    %{"q" => %{"e_day" => @regexify.("already voted")}, "label" => "e_day_already_voted"},
    %{"q" => %{"e_day" => @regexify.("not_voting")}, "label" => "e_day_not_voting"}
  ]

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
    queue_update()
    {:ok, %{}}
  end

  def queue_update do
    spawn(fn ->
      :timer.sleep(@run_every)
      report_over_period()
    end)
  end

  def report_over_period do
    service_names =
      Livevox.ServiceInfo.all_services()
      |> Enum.map(&Livevox.ServiceInfo.name_of/1)

    Enum.map(@intervals, fn interval ->
      Enum.map(service_names, fn name ->
        Enum.map(@queries, fn query ->
          report_over_period(interval, name, query)
        end)
      end)
    end)
  end

  def report_over_period(minutes_ago, service, ~m(q label)) do
    time_after = Timex.shift(Timex.now(), minutes: -1 * minutes_ago)

    timestamp = %{"$gt" => time_after}
    service_name = service

    {:ok, count} = Db.count("calls", Map.merge(q, ~m(service_name timestamp)))

    Dog.post_metric("call_count", [Timex.now(), count], ["service_name:#{service}", label])
  end
end
