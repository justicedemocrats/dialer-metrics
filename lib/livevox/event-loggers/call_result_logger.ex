defmodule Livevox.EventLoggers.CallResult do
  alias Phoenix.{PubSub}
  use GenServer
  import ShortMaps

  def login_management_url, do: Application.get_env(:livevox, :login_management_url)

  def start_link do
    GenServer.start_link(
      __MODULE__,
      fn ->
        %{}
      end,
      name: __MODULE__
    )
  end

  def init(opts) do
    PubSub.subscribe(:livevox, "agent_event")
    {:ok, %{}}
  end

  # Successful calls from agent event feed
  def handle_info(
        message = %{"lineNumber" => "ACD", "eventType" => "WRAP_UP", "result" => _},
        state
      ) do

    ~m(id) = call = Livevox.EventLoggers.ProcessCall.from_agent_fully(message)
    Db.update("calls", ~m(id), call)

    {:noreply, state}
  end

  def handle_info(_, _) do
    {:noreply, %{}}
  end
end
