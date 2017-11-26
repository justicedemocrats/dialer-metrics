defmodule Livevox.DummyFeed do
  @moduledoc """
  Documentation for Livevox.
  """

  @doc """
  """
  defmacro __using__(_) do
    quote do
      use Agent

      def start_link do
        Task.start_link(fn -> get_calls() end)
      end

      def get_calls do
        :timer.sleep(1000)
        get_calls
      end
    end
  end
end
