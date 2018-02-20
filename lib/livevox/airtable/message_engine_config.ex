defmodule Livevox.MessageEngineConfig do
  use AirtableConfig
  import ShortMaps

  def base, do: Application.get_env(:livevox, :message_engine_base)
  def table, do: Application.get_env(:livevox, :message_engine_table_name)
  def key, do: Application.get_env(:livevox, :message_engine_key)
  def view, do: "Grid view"
  def into_what, do: []

  def filter_record(~m(fields)) do
    fields["Active"] == true
  end

  def process_record(~m(fields)) do
    {:ok, service_regex} = Regex.compile(fields["Service Regex"])
    active_time_range = fields["Active Time Range (EST)"]
    seconds_in_not_ready = fields["Seconds in Not Ready"]
    action = fields["Action"]
    message = fields["Message"]
    reference_name = fields["Reference Name"]
    trigger_despite_competence = fields["Trigger Despite Competence"]

    ~m(service_regex active_time_range seconds_in_not_ready action message reference_name trigger_despite_competence)
  end
end
