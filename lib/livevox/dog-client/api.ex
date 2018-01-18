defmodule Dog.Api do
  use HTTPotion.Base

  def default_query do
    %{
      api_key: Application.get_env(:livevox, :data_dog_api_key),
      application_key: Application.get_env(:livevox, :data_dog_application_key)
    }
  end

  # --------------- Process request ---------------
  defp process_url(url) do
    "https://app.datadoghq.com/api/v1/#{url}"
  end

  defp process_request_headers(hdrs) do
    Enum.into(hdrs, Accept: "application/json", "Content-Type": "application/json")
  end

  defp process_options(opts) do
    Keyword.update(opts, :query, default_query, fn params ->
      Map.merge(default_query, params)
    end)
  end

  defp process_request_body(body) when is_map(body) do
    case Poison.encode(body) do
      {:ok, encoded} -> encoded
      {:error, problem} -> problem
    end
  end

  defp process_request_body(body) do
    body
  end

  # --------------- Process response ---------------
  defp process_response_body(raw) do
    case Poison.decode(raw) do
      {:ok, body} -> body
      {:error, raw, _} -> {:error, raw}
    end
  end
end
