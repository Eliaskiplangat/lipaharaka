defmodule LipaharakaWeb.Router do
  use LipaharakaWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Composed with :api (see pipe_through [:api, :authenticated] below).
  # Verifies the bearer token and assigns conn.assigns.current_user, or
  # halts the request with a 401 before it reaches the controller.
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

    post "/businesses", BusinessController, :create
    get "/businesses/me", BusinessController, :show
    patch "/businesses/me", BusinessController, :update

    # Step 5 will add here: KYC document upload
    #   post "/businesses/me/kyc_documents", KycDocumentController, :create
  end
end
