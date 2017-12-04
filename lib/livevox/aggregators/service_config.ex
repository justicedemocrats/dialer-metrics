defmodule Livevox.Aggregators.ServiceConfig do
  alias Phoenix.PubSub
  import ShortMaps

  @resolution 60_000 * 3600
  @key Application.get_env(:livevox, :airtable_key)
  @base Application.get_env(:livevox, :airtable_base)
  @table "Services"


  def start_link do
    Task.start_link(fn -> get_service_info() end)
  end

  def get_service_info do
    %{body: ~m(stats)} = Livevox.Api.post("realtime/v6.0/service/stats", body: %{})
    timestamp = DateTime.utc_now()

    from_stats =
      Enum.map(stats, fn ~m(pacingMethod throttle serviceName serviceId) ->
        {
          serviceId,
          %{
            pacing_method: pacingMethod,
            throttle: throttle,
            service_name: serviceName
          }
        }
      end)
      |> Enum.into(%{})

    %{body: ~m(lcidPackage)} =
      Livevox.Api.get("configuration/v6.0/lcidPackages", query: %{offset: 0, count: 1000})

    lcid_package_ids = Enum.map(lcidPackage, fn ~m(id) -> id end)

    services_with_lcid =
      Enum.flat_map(lcid_package_ids, fn id ->
        %{body: ~m(service)} = Livevox.Api.get("configuration/v6.0/lcidPackages/#{id}")
        Enum.map(service, fn ~m(id) -> "#{id}" end)
      end)
      |> MapSet.new()

    services_without_lcid =
      Map.keys(from_stats) |> Enum.reject(fn sid -> MapSet.member?(services_with_lcid, sid) end)

    service_phones = Enum.map(services_without_lcid, fn id ->
      %{body: ~m(defaultCallerId)} = Livevox.Api.get("configuration/v6.0/services/#{id}/phone")
      {id, defaultCallerId}
    end) |> Enum.into(%{})

    %{body: ~m(resourceGroup)} = Livevox.Api.get("configuration/v6.0/resourceGroups", query: %{offset: 0, count: 1000})

    resource_groups = Enum.flat_map(resourceGroup, fn ~m(id) ->
      %{body: ~m(name inboundService outboundService)} =
        Livevox.Api.get("configuration/v6.0/resourceGroups/#{id}")

      Enum.concat(inboundService, outboundService)
      |> Enum.map(fn ~m(id) -> "#{id}" end)
      |> Enum.map(fn sid -> {sid, name} end)
    end) |> Enum.into(%{})

    final_services = Enum.map(from_stats, fn {id, map} ->
      updated_map = map
      |> Map.put(:caller_id_type, (if MapSet.member?(services_with_lcid, id), do: "LCID", else: "Fixed"))
      |> Map.put(:caller_id_number, Map.get(service_phones, id, ""))
      |> Map.put(:resource_group, Map.get(resource_groups, id, ""))

      {id, updated_map}
    end)

    # Delete all records
    %{body: body} =
      HTTPotion.get("https://api.airtable.com/v0/#{@base}/#{@table}", headers: [
        Authorization: "Bearer #{@key}"
      ])

    decoded = Poison.decode!(body)

    Enum.each(decoded["records"], fn ~m(id) ->
      HTTPotion.delete("https://api.airtable.com/v0/#{@base}/#{@table}/#{id}", headers: [
        Authorization: "Bearer #{@key}"
      ])
    end)

    # Create all records
    Enum.each final_services, fn {service_id, attributes} ->
      ~m(caller_id_number caller_id_type pacing_method resource_group service_name throttle)a = attributes

      fields = %{
        "Service ID" => service_id,
        "Service Name" => service_name,
        "Resource Group" => resource_group,
        "Pacing Method" => pacing_method,
        "Throttle" => throttle,
        "Caller Id Type" => caller_id_type,
        "Caller Id Number" => caller_id_number
      }

      HTTPotion.post(
        "https://api.airtable.com/v0/#{@base}/#{@table}",
        headers: [
          Authorization: "Bearer #{@key}",
          "Content-Type": "application/json"
        ],
        body: ~m(fields) |> Poison.encode!()
      )
    end

    :timer.sleep(@resolution)
    get_service_info()
  end
end
