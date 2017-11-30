defmodule Livevox.Metrics.ServiceLevel do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn -> %{} end)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "service_cip")
    {:ok, %{}}
  end

  def handle_info(
        ~m(service_name timestamp cip percent_complete playing_dialable throttle)a,
        state
      ) do
    unixy = DateTime.to_unix(timestamp)

    series =
      Enum.map(~m(cip percent_complete playing_dialable throttle)a, fn {key, val} ->
        %{metric: Atom.to_string(key), points: [[unixy, as_float(val)]], tags: [service_name]}
      end)

    Dog.post_metrics(series)
    {:noreply, %{}}
  end

  defp as_float(val) when is_binary(val) do
    {f, _} = Float.parse(val)
    f
  end

  defp as_float(val) when is_float(val) do
    val
  end

  defp as_float(val) when is_integer(val) do
    val
  end
end
