defmodule ScreenBoard do
  def duplicate(board_id, new_title, replacements) do
    %{body: original} = Dog.Api.get("screen/#{board_id}")

    duplicate =
      original
      |> Map.drop(~w(id created created_by title_edited))
      |> Map.put("board_title", new_title)
      |> Map.update!("widgets", fn widget_list ->
           Enum.map(widget_list, fn widget ->
             if widget["tile_def"] != nil and widget["tile_def"]["requests"] != nil do
               update_in(widget, ~w(tile_def requests), fn requests ->
                 Enum.map(requests, fn req ->
                   Map.update!(req, "q", fn string ->
                     # if String.contains?(string, "call_count") do
                       Enum.reduce(replacements, string, fn {match, replace}, acc ->
                         String.replace(acc, match, replace, global: true)
                       end)
                     # else
                     #   string
                     # end
                   end)
                 end)
               end)
             else
               widget
             end
           end)
         end)

    IO.inspect(Dog.Api.post("screen", body: duplicate))
  end
end
