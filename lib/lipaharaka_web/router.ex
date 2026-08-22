defmodule LipaharakaWeb.Router do
  use LipaharakaWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end


  pipeline :authenticated do
    plug LipaharakaWeb.Plugs.RequireAuth
  end

  scope "/api", LipaharakaWeb do
    pipe_through :api

    get "/health", HealthController, :index

    post "/auth/register", AuthController, :register
    post "/auth/verify_otp", AuthController, :verify_otp
    post "/auth/resend_otp", AuthController, :resend_otp
    post "/auth/login", AuthController, :login
  end

  scope "/api", LipaharakaWeb do
    pipe_through [:api, :authenticated]

    get "/me", AuthController, :me


  end
end
