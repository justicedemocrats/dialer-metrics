defmodule Livevox.AirtableCache do
  use Agent

  def key, do: Application.get_env(:livevox, :airtable_key)
  def base, do: Application.get_env(:livevox, :airtable_base)
  def table, do: Application.get_env(:livevox, :airtable_table_name)

  def start_link do
    Agent.start_link(
      fn ->
        fetch_all()
      end,
      name: __MODULE__
    )
  end

  def update() do
    Agent.update(__MODULE__, fn _current ->
      fetch_all()
    end)

    IO.puts("[term codes]: updated at #{inspect(DateTime.utc_now())}")
  end

  def get_all do
    Agent.get(__MODULE__, & &1)
  end

  defp fetch_all() do
    %{body: body} =
      HTTPotion.get("https://api.airtable.com/v0/#{base}/#{table}", headers: [
        Authorization: "Bearer #{key}"
      ])

    decoded = Poison.decode!(body)

    records = process_records(decoded["records"])

    if Map.has_key?(decoded, "offset") do
      fetch_all(records, decoded["offset"])
    else
      records
    end
  end

  defp fetch_all(records, offset) do
    %{body: body} =
      HTTPotion.get(
        "https://api.airtable.com/v0/#{base}/#{table}",
        headers: [
          Authorization: "Bearer #{key}"
        ],
        query: [offset: offset]
      )

    decoded = Poison.decode!(body)

    new_records = process_records(decoded["records"])
    all_records = Enum.into(records, new_records)

    if Map.has_key?(decoded, "offset") do
      fetch_all(all_records, decoded["offset"])
    else
      all_records
    end
  end

  defp typey_downcase(val) when is_binary(val), do: String.downcase(val)
  defp typey_downcase(val), do: val

  defp process_records(records) do
    records
    |> Enum.filter(fn %{"fields" => fields} -> Map.has_key?(fields, "LV System Result") end)
    |> Enum.reduce(%{}, fn %{"fields" => fields}, acc ->
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

         Map.put(acc, key, Map.drop(underscored, ["lv_result", "lv_system_result"]))
       end)
  end
end
