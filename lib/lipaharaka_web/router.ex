defmodule LipaharakaWeb.Router do
  use LipaharakaWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LipaharakaWeb do
    pipe_through :api

    get "/health", HealthController, :index


    # Step 2 will add here:
    #   post "/auth/register", AuthController, :register
    #   post "/auth/verify_otp", AuthController, :verify_otp
    #   post "/auth/login", AuthController, :login
  end
end
