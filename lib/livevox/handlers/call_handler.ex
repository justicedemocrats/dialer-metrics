defmodule Livevox.CallHandler do
  use Livevox.CallEventFeed

  def handle_call_event(call_event) do
    Livevox.State.Calls.handle_call_event(call_event)
  end
end
