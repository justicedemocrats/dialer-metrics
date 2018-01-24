defmodule LivevoxWeb.LiveController do
  use LivevoxWeb, :controller
  import ShortMaps
  alias Livevox.Metrics.ServiceLevel
  alias Livevox.Aggregators.AgentStatus
  alias Livevox.ServiceInfo

  def health(conn, _) do
    json(conn, %{"healthy" => true})
  end

  def global_state(conn, _) do
    global_state = get_global_state
    json(conn, global_state)
  end

  def pacing_method(conn, ~m(service)) do
    response =
      case ServiceLevel.pacing_method_of(service) do
        nil ->
          options = ServiceLevel.service_name_options() |> Enum.sort() |> Enum.join("\n")
          "Hm, that service was not recognized. Please try one of #{options}"

        pacing ->
          pacing
      end

    conn
    |> delete_resp_header("x-frame-options")
    |> text(response)
  end

  def pacing_method(conn, _) do
    conn
    |> delete_resp_header("x-frame-options")
    |> text("Missing service – proper usage is GET /pacing-method/:service")
  end

  def agent_status(conn, ~m(service)) do
    conn
    |> delete_resp_header("x-frame-options")
    |> render("agent-status.html", service_name: service)
  end

  def agent_status(conn, _) do
    conn
    |> delete_resp_header("x-frame-options")
    |> text("Missing service – proper usage is GET /agent-status/:service")
  end

  def control_throttle(conn, ~m(service)) do
    conn
    |> delete_resp_header("x-frame-options")
    |> render("control-throttle.html", service_name: service)
  end

  def control_throttle(conn, _) do
    conn
    |> delete_resp_header("x-frame-options")
    |> text("Missing service – proper usage is GET /control-pacing/:service")
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
