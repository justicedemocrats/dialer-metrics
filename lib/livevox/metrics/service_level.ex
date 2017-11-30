defmodule Livevox.Metrics.ServiceLevel do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(__MODULE__, fn ->
      %{}
    end)
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "service_stats")
    {:ok, %{}}
  end

  def handle_info(message = %{service_name: service_name, timestamp: timestamp}, _state) do
    timestamp = DateTime.to_unix(timestamp)

    series =
      Map.drop(message, ~w(service_name timestamp)a)
      |> Enum.map(fn {metric, val} ->
           %{
             metric: Atom.to_string(metric),
             points: [[timestamp, val]],
             tags: ["service:#{service_name}"]
           }
         end)

    Dog.post_metrics(series)

    {:noreply, %{}}
  end
end
