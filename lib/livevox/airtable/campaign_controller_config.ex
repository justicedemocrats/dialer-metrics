defmodule Livevox.CampaignControllerConfig do
  use AirtableConfig
  import ShortMaps

  def base, do: Application.get_env(:livevox, :campaign_controller_base)
  def table, do: Application.get_env(:livevox, :campaign_controller_table_name)
  def key, do: Application.get_env(:livevox, :campaign_controller_key)
  def view, do: "Grid view"
  def into_what, do: []

  def filter_record(~m(fields)) do
    Map.has_key?(fields, "Start Time (EST)")
  end

  def process_record(~m(fields)) do
    {:ok, service_regex} =
      Regex.compile(fields["Service Regex"] |> String.trim() |> String.downcase())

    active_days = fields["Active Days of the Week"]
    start_time = fields["Start Time (EST)"]
    end_time = fields["End Time (EST)"]
    ~m(service_regex active_days start_time end_time)
  end
end
