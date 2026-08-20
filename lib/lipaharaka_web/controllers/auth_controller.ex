defmodule LipaharakaWeb.AuthController do
  use LipaharakaWeb, :controller

  alias Lipaharaka.Accounts


  def register(conn, params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> render(:registered, user: user)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset_error, changeset: changeset)
    end
  end


  def verify_otp(conn, %{"phone_number" => phone, "otp" => otp}) do
    case Accounts.verify_otp(phone, otp) do
      {:ok, user} ->
        render(conn, :verified, user: user)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:otp_error, reason: reason)
    end
  end


  def verify_otp(conn, _params), do: bad_request(conn, "phone_number and otp are required")
  def resend_otp(conn, %{"phone_number" => phone}) do
    with {:ok, normalized} <- Lipaharaka.Accounts.PhoneNumber.normalize(phone),
         %Lipaharaka.Accounts.User{} = user <- Accounts.get_user_by_phone(normalized) do
      {:ok, _user} = Accounts.issue_and_send_otp(user)

      conn
      |> put_status(:ok)
      |> json(%{message: "A new verification code has been sent."})
    else
      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{phone_number: "not found"}})
    end
  end

  def resend_otp(conn, _params), do: bad_request(conn, "phone_number is required")

  def login(conn, %{"phone_number" => phone, "password" => password}) do
    case Accounts.authenticate(phone, password) do
      {:ok, user} ->
        render(conn, :logged_in, user: user)

      {:error, :phone_not_verified} ->
        conn
        |> put_status(:forbidden)
        |> json(%{errors: %{phone_number: "not verified — please verify your phone first"}})

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "invalid phone number or password"}})
    end
  end

  def login(conn, _params), do: bad_request(conn, "phone_number and password are required")

  defp bad_request(conn, message) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: message}})
  end
end
