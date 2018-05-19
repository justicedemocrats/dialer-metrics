defmodule LivevoxWeb.ApiController do
  use LivevoxWeb, :controller
  import ShortMaps
  alias Livevox.Metrics.ServiceLevel
  alias Livevox.Aggregators.AgentStatus
  alias Livevox.ServiceInfo

  def agent_desktop_info(conn, ~m(service_name)) do
    [caller_count, wait_time] = get_agent_desktop_info(service_name)
    json(conn, ~m(caller_count wait_time))
  end

  def get_agent_desktop_info(service_name) do
    [
      Task.async(fn ->
        ~m(active)a =
          AgentStatus.get_breakdown(%{
            "service_name" =>
              service_name
              |> String.downcase()
              |> String.replace(" ", "_", global: true)
          })

        length(active)
      end),
      Task.async(fn ->
        %{body: ~m(series)} =
          Dog.Api.get(
            "query",
            query: %{
              "from" => Timex.now() |> Timex.shift(minutes: -5) |> DateTime.to_unix(),
              "to" => Timex.now() |> DateTime.to_unix(),
              "query" => "avg:wait_time{service:#{slugify(service_name)}}"
            }
          )

        case series do
          [first | _] ->
            points = Enum.map(first["pointlist"], &List.last(&1))
            Enum.sum(points) / length(points)

          _ ->
            nil
        end
      end)
    ]
    |> Enum.map(&Task.await/1)
  end

  def rebuild_dashboard(conn, _) do
    ScreenBoard.Jobs.reconstruct_manager()
    text(conn, "dashboard rebuilt.")
  end

  def slugify(service_name) do
    service_name
    |> String.replace(" ", "_", global: true)
    |> String.downcase()
  end
end
