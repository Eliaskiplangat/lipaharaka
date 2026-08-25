defmodule Lipaharaka.AccountsRoleTest do
  use Lipaharaka.DataCase, async: false

  alias Lipaharaka.Accounts

  setup do
    Lipaharaka.SMS.Test.clear()
    :ok
  end

  test "role defaults to sme and cannot be set via registration params" do
    attrs = %{
      "phone_number" => "0712345678",
      "password" => "supersecret",
      # A client attempting to self-promote — must be silently ignored.
      "role" => "admin"
    }

    assert {:ok, user} = Accounts.register_user(attrs)
    assert user.role == "sme"
  end

  test "promote_to_admin/1 sets the role" do
    {:ok, user} =
      Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})

    assert user.role == "sme"
    assert {:ok, promoted} = Accounts.promote_to_admin(user)
    assert promoted.role == "admin"
  end
end
