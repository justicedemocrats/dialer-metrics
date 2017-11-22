defmodule LivevoxWeb.Router do
  use LivevoxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LivevoxWeb do
    pipe_through :api

    post "/claim/:campaign", AccountController, :claim
  end
end
