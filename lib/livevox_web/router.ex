defmodule LivevoxWeb.Router do
  use LivevoxWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", LivevoxWeb do
    pipe_through(:api)

    # Accepts ?ready=true and ?ready=false
    get("/health", LiveController, :health)
    get("/global-state", LiveController, :global_state)
  end
end
