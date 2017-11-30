defmodule Dog do
  import ShortMaps

  def post_metric(metric, point, tags) do
    ~m(timestamp value)a = Map.get_and_update!(point, :timestamp, &timeify/1)
    points = [[timestamp, value]]
    Dog.Api.post("series", body: %{series: [~m(metric points tags)]})
  end

  def post_metrics(metrics) do
    series = Enum.map(metrics, [])
    Dog.Api.post("series", body: ~m(series)a |> IO.inspect())
  end

  def post_event(event = %Dog.Event{}) do
    event = Map.get_and_update!(event, :date_happened, &timeify/1)
    Dog.Api.post("events", body: event)
  end

  def delete_all_events do
    query_start = Timex.shift(Timex.now(), days: -20) |> DateTime.to_unix()
    query_end = Timex.shift(Timex.now(), days: 1) |> DateTime.to_unix()

    %{body: %{"events" => events}} =
      Dog.Api.get("events", query: %{start: query_start, end: query_end})

    Enum.each(events, fn %{"id" => id} ->
      Dog.Api.delete("events/${id}")
    end)
  end

  defp gen_timeify(key) do
    fn map ->
      Map.get_and_update(map, key, &timeify/1)
    end
  end

  defp timeify(ts) when is_integer(ts), do: ts
  defp timeify(ts) when is_map(ts), do: DateTime.to_unix(ts)
end
