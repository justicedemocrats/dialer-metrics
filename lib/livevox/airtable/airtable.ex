defmodule Livevox.AirtableCache do
  import ShortMaps
  use AirtableConfig

  def key, do: Application.get_env(:livevox, :airtable_key)
  def base, do: Application.get_env(:livevox, :airtable_base)
  def table, do: Application.get_env(:livevox, :airtable_table_name)
  def view, do: "Grid view"
  def into_what, do: %{}

  def filter_record(~m(fields)) do
    Map.has_key?(fields, "LV System Result")
  end

  def process_record(~m(fields)) do
    underscored =
      Enum.map(fields, fn {key, val} ->
        {
          key |> String.replace(" ", "") |> Macro.underscore(),
          typey_downcase(val)
        }
      end)
      |> Enum.into(%{})

    key =
      case underscored["lv_result"] do
        nil -> underscored["lv_system_result"]
        "" -> underscored["lv_system_result"]
        something -> Livevox.Standardize.term_code(something)
      end

    val = Map.drop(underscored, ["lv_result", "lv_system_result"])
    {key, val}
  end

  defp typey_downcase(val) when is_binary(val), do: String.downcase(val)
  defp typey_downcase(val), do: val
end
