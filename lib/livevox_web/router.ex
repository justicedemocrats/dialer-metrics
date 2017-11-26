defmodule LivevoxWeb.Router do
  use LivevoxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/account", LivevoxWeb do
    pipe_through :api

    post "/claim/:service", AccountController, :claim
  end

  scope "/live", LivevoxWeb do
    pipe_through :api

    # Accepts ?ready=true and ?ready=false
    get "/agent-count/:service", LiveController, :agent_count
    get "/calls-in-progress/:service", LiveController, :call_count
  end
end
