defmodule Livevox.ClientInfo do
  def get_client_name(service_name) do
    cond do
      String.contains?(service_name, "Beto") -> "beto"
      true -> "jd"
    end
  end
end
