defmodule Livevox.Metrics.ServiceLevel do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def start_link do
    GenServer.start_link(
      __MODULE__,
      fn ->
        %{}
      end,
      name: __MODULE__
    )
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "service_stats")
    {:ok, %{}}
  end

  def handle_info(message = %{service_name: service_name, timestamp: timestamp}, state) do
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

    spawn(fn -> Dog.post_metrics(series) end)

    url_service_name =
      service_name
      |> String.downcase()
      |> String.replace(" ", "_")

    new_state = Map.put(state, url_service_name, Map.drop(message, ~w(service_name timestamp)a))

    {:noreply, new_state}
  end

  def pacing_method_of(service_name) do
    url_service_name =
      service_name
      |> String.downcase()
      |> String.replace(" ", "_")

    :sys.get_state(__MODULE__)
    |> get_in([service_name, :pacing_method])
  end

  def service_name_options do
    :sys.get_state(__MODULE__)
    |> Map.keys()
  end
end
