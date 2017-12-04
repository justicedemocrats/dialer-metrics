defmodule LivevoxWeb.LiveController do
  use LivevoxWeb, :controller
  import ShortMaps
  alias Livevox.Metrics.ServiceLevel

  def health(conn, _) do
    json(conn, %{"healthy" => true})
  end

  def global_state(conn, _) do
    global_state = get_global_state
    json(conn, global_state)
  end

  def pacing_method(conn, ~m(service)) do
    case ServiceLevel.pacing_method_of(service) do
      nil ->
        options = Enum.join(ServiceLevel.service_name_options(), ",")
        message = "Hm, that service was not recognized. Please try one of #{options}"
        text(conn, message)

      pacing -> text conn, pacing
    end
  end

  def pacing_method(conn, _) do
    text conn, "Missing service – proper usage is GET /pacing-method/:service"
  end

  def get_global_state do
    Enum.reduce(
      [
        Livevox.Metrics.CallerCounts,
        Livevox.Metrics.ServiceLevel,
        Livevox.Metrics.WaitTime,
        Livevox.Metrics.SessionLength,
        Livevox.Metrics.CallLength
      ],
      %{},
      fn process_name, acc ->
        Map.put(acc, process_name, :sys.get_state(process_name))
      end
    )
  end
end
