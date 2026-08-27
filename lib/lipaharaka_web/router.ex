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

  # Composed with [:api, :authenticated] — RequireAdmin runs AFTER
  # RequireAuth, so conn.assigns.current_user is guaranteed present by
  # the time it checks the role. A non-admin gets a 403 here, distinct
  # from the 401 an unauthenticated request gets from :authenticated.
  pipeline :admin do
    plug LipaharakaWeb.Plugs.RequireAdmin
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

    post "/businesses/me/kyc_documents", KycDocumentController, :create
    get "/businesses/me/kyc_documents", KycDocumentController, :index

    post "/invoices", InvoiceController, :create
    get "/invoices", InvoiceController, :index
    get "/invoices/:id", InvoiceController, :show
    patch "/invoices/:id", InvoiceController, :update
    post "/invoices/:id/send", InvoiceController, :send_invoice
    post "/invoices/:id/mark_paid", InvoiceController, :mark_paid
    post "/invoices/:id/cancel", InvoiceController, :cancel
  end

  scope "/api/admin", LipaharakaWeb do
    pipe_through [:api, :authenticated, :admin]

    get "/kyc_documents/pending", Admin.KycDocumentController, :pending
    patch "/kyc_documents/:id", Admin.KycDocumentController, :review

    # A future step will add here: automated collections/reminders
    # (FR-3.x) and M-Pesa payment integration (FR-4.x).
  end
end
