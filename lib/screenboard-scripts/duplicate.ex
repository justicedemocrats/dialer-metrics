defmodule ScreenBoard do
  import ShortMaps

  def list do
    %{body: ~m(screenboards)} = Dog.Api.get("screen")

    Enum.map(screenboards, fn ~m(title id) ->
      IO.puts("#{id}: #{title}")
      {id, title}
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
          requests == nil ->
            w

          Regex.run(~r/.*\/.*,total.*/, List.first(requests) |> Map.get("q")) != nil ->
            first_request = List.first(requests)
            q = Map.get(first_request, "q")
            new_q = Regex.replace(~r/,total/, q, ",dialed")
            new_request = Map.put(first_request, "q", new_q)
            IO.inspect(put_in(w, ~w(tile_def requests), [new_request]))

          true ->
            w
        end
      end)

    new_board = Map.put(board, "widgets", new_widgets)
    IO.inspect(Dog.Api.put("screen/#{board_id}", body: new_board))
  end

  def set_interval_to_10(board_id) do
    %{body: board} = Dog.Api.get("screen/#{board_id}")

    new_widgets =
      board["widgets"]
      |> Enum.map(fn w ->
        if extract_q(w) |> contains_any?(~w(loaded percent_complete remaining throttle)) do
          Map.put(w, "timeframe", "10m")
        else
          w
        end
      end)

    new_board = Map.put(board, "widgets", new_widgets)
    IO.inspect(Dog.Api.put("screen/#{board_id}", body: new_board))
  end

  def extract_q(%{"tile_def" => ~m(requests)}) do
    case List.first(requests) do
      ~m(q) -> q
      _ -> nil
    end
  end

  def extract_q(_) do
    nil
  end

  def contains_any?(string, options) when is_binary(string) do
    options
    |> Enum.filter(&String.contains?(string, &1))
    |> length()
    |> (&(&1 > 0)).()
  end

  def contains_any?(_, _) do
    false
  end
end
