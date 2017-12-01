defmodule LivevoxWeb.LiveController do
  use LivevoxWeb, :controller

  def health(conn, _) do
    json(conn, %{"healthy" => true})
  end

  def global_state(conn, _) do
    global_state = get_global_state
    json(conn, global_state)
  end

  def get_global_state do
    Enum.reduce(
      [
        Livevox.Metrics.CallerCounts,
        Livevox.Metrics.ServiceLevel,
        Livevox.Metrics.WaitTime,
        Livevox.Metrics.SessionLength,
        Livevox.Metrics.CallLength
      ],
      %{},
      fn process_name, acc ->
        Map.put(acc, process_name, :sys.get_state(process_name))
      end
    )
  end
end
