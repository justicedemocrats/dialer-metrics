defmodule ScreenBoard do
  import ShortMaps

  def list do
    %{body: ~m(screenboards)} = Dog.Api.get("screen")

    Enum.each(screenboards, fn ~m(title id) ->
      IO.puts "#{id}: #{title}"
    end)
  end

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

  def replace_total_with_dialed(board_id) do
    %{body: board} = Dog.Api.get("screen/#{board_id}")

    new_widgets =
      board["widgets"]
      |> Enum.map(fn w ->
        requests = get_in(w, ~w(tile_def requests))

        cond do
          requests == nil -> w

          Regex.run(~r/.*\/.*,total.*/, (List.first(requests) |> Map.get("q"))) != nil ->
            first_request = List.first(requests)
            q = Map.get(first_request, "q")
            new_q = Regex.replace(~r/,total/, q, ",dialed")
            new_request = Map.put(first_request, "q", new_q)
            IO.inspect put_in(w, ~w(tile_def requests), [new_request])

          true -> w
        end
      end)

    new_board = Map.put(board, "widgets", new_widgets)
    IO.inspect Dog.Api.put("screen/#{board_id}", body: new_board)
  end
end
