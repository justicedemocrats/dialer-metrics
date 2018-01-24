defmodule LivevoxWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :livevox

  socket("/socket", LivevoxWeb.UserSocket)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Logger)

  # parsers: [:urlencoded, :multipart, :json],
  plug(
    Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(
    Plug.Static,
    at: "/",
    from: :livevox,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(LivevoxWeb.Router)

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
