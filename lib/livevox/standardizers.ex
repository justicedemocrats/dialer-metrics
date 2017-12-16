defmodule Livevox.Standardize do
  def term_code(code) do
    code
    |> String.replace(~r/[ ]+\(.*\)[ ]*/, "")
  end
end
