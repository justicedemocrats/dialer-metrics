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
    get("/pacing-method", LiveController, :pacing_method)
    get("/pacing-method/:service", LiveController, :pacing_method)
    get("/agent-status", LiveController, :agent_status)
    get("/agent-status/:service", LiveController, :agent_status)
    get("/throttle", LiveController, :control_throttle)
    get("/throttle/:service", LiveController, :control_throttle)
  end

  scope "/api", LivevoxWeb do
    get("/agent-desktop-info", ApiController, :agent_desktop_info)
    get("/rebuild-dashboard", ApiController, :rebuild_dashboard)
  end
end
