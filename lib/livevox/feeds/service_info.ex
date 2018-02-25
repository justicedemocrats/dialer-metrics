defmodule Livevox.ServiceInfo do
  import ShortMaps
  use Agent

  def start_link do
    Agent.start_link(fn -> fetch_all() end, name: __MODULE__)
  end

  def update() do
    Agent.update(__MODULE__, fn _current ->
      fetch_all()
    end)

    IO.puts("[service info]: updated at #{inspect(DateTime.utc_now())}")
  end

  def fetch_all do
    %{body: %{"callCenter" => centers}} =
      Livevox.Api.get("configuration/v6.0/callCenters", query: %{count: 1000, offset: 0})

    centers
    |> Enum.map(fn %{"callCenterId" => cid} -> cid end)
    |> Enum.flat_map(fn cid ->
      %{body: %{"service" => services}} =
        Livevox.Api.get(
          "configuration/v6.0/services",
          query: %{
            callCenter: cid,
            count: 1000,
            offset: 0
          }
        )

      services
    end)
    |> Enum.map(fn ~m(name serviceId) -> {serviceId, name} end)
    |> Enum.into(%{})
  end

  def name_of(service_id) do
    Agent.get(__MODULE__, fn state ->
      Map.get(state, service_id, nil)
    end)
  end

  def all_services() do
    Agent.get(__MODULE__, fn state ->
      Map.keys(state)
    end)
  end

  def id_of(service_name) do
    Agent.get(__MODULE__, fn state ->
      Enum.filter(state, fn {_id, name} ->
        url_service_name =
          name
          |> String.downcase()
          |> String.replace(" ", "_")

        url_service_name == service_name
      end)
      |> Enum.map(fn {id, _name} -> id end)
      |> List.first()
    end)
  end
end
