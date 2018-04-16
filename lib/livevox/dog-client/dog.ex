defmodule Dog do
  import ShortMaps
  require Logger
  @live not (Application.get_env(:livevox, :test) == true)

  def post_metric(metric, point, tags) do
    [timestamp, value] = point
    points = [[timeify(timestamp), value]]
    type = "gauge"

    if @live do
      Dog.Api.post("series", body: %{series: [~m(metric points tags type)]})
    else
      Logger.debug("DOG: post single series: #{inspect(~m(metric points tags type))}")
    end
  end

  def post_metrics(series) do
    if @live do
      Dog.Api.post("series", body: ~m(series)a)
    else
      Logger.debug("DOG: post series: #{inspect(series)}")
    end
  end

  def post_event(event) do
    event = Map.update!(event, :date_happened, &timeify/1)
    md5 = md5_event(event)

    if @live do
      Dog.Api.post("events", body: event)
    else
      Logger.debug("DOG: post event: #{md5}")
    end
  end

  defp md5_event(_ev = %{tags: tags}) do
    :crypto.hash(:md5, Enum.join(tags, "-")) |> Base.encode16(case: :lower)
  end

  # defp md5_metric(~m(points tags)) do
  #   md5 = :crypto.hash(:md5, Enum.join(tags, "-")) |> Base.encode16(case: :lower)
  #   Enum.reduce(points, 0, fn [_, n], sum -> sum + n end)
  #   "#{md5}: #{inspect(points)}"
  # end

  # defp md5_metric(~m(points tags)a) do
  #   md5 = :crypto.hash(:md5, Enum.join(tags, "-")) |> Base.encode16(case: :lower)
  #   Enum.reduce(points, 0, fn [_, n], sum -> sum + n end)
  #   "#{md5}: #{inspect(points)}"
  # end

  def delete_all_events do
    query_start = Timex.shift(Timex.now(), days: -20) |> DateTime.to_unix()
    query_end = Timex.shift(Timex.now(), days: 1) |> DateTime.to_unix()

    %{body: %{"events" => events}} =
      Dog.Api.get("events", query: %{start: query_start, end: query_end})

    Enum.each(events, fn ~m(id) ->
      Dog.Api.delete("events/#{id}")
    end)
  end

  # defp gen_timeify(key) do
  #   fn map ->
  #     Map.update!(map, key, &timeify/1)
  #   end
  # end

  defp timeify(ts) when is_integer(ts), do: ts
  defp timeify(ts) when is_map(ts), do: DateTime.to_unix(ts, :second)
end
