defmodule Lipaharaka.AccountsTest do
  use Lipaharaka.DataCase, async: false

  alias Lipaharaka.Accounts

  setup do
    Lipaharaka.SMS.Test.clear()
    :ok
  end

  @valid_attrs %{"phone_number" => "0712345678", "password" => "supersecret"}

  describe "register_user/1" do
    test "creates a user, normalizes the phone number, and sends an OTP" do
      assert {:ok, user} = Accounts.register_user(@valid_attrs)
      assert user.phone_number == "+254712345678"
      assert is_nil(user.phone_verified_at)
      refute is_nil(user.otp_hash)

      message = Lipaharaka.SMS.Test.last_message_to("+254712345678")
      assert message =~ "verification code"
    end

    test "rejects a duplicate phone number" do
      assert {:ok, _user} = Accounts.register_user(@valid_attrs)

      assert {:error, changeset} = Accounts.register_user(@valid_attrs)
      assert "has already been taken" in errors_on(changeset).phone_number
    end

    test "rejects an invalid phone number" do
      attrs = Map.put(@valid_attrs, "phone_number", "12345")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "is not a valid Kenyan phone number" in errors_on(changeset).phone_number
    end

    test "rejects a short password" do
      attrs = Map.put(@valid_attrs, "password", "short")
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert errors_on(changeset).password != []
    end

    test "accepts alternate Kenyan phone formats and normalizes them the same way" do
      for phone <- ["+254712345678", "254712345678", "0712345678"] do
        Lipaharaka.Repo.delete_all(Lipaharaka.Accounts.User)
        assert {:ok, user} = Accounts.register_user(Map.put(@valid_attrs, "phone_number", phone))
        assert user.phone_number == "+254712345678"
      end
    end
  end

  describe "verify_otp/2" do
    test "verifies the correct code and marks the phone verified" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      otp = extract_otp(user.phone_number)

      assert {:ok, verified_user} = Accounts.verify_otp(user.phone_number, otp)
      refute is_nil(verified_user.phone_verified_at)
      assert is_nil(verified_user.otp_hash)
    end

    test "rejects an incorrect code" do
      {:ok, user} = Accounts.register_user(@valid_attrs)

      assert {:error, :incorrect} = Accounts.verify_otp(user.phone_number, "000000")
    end

    test "rejects a code for a phone number that was never registered" do
      assert {:error, :not_found} = Accounts.verify_otp("+254799999999", "123456")
    end
  end

  describe "authenticate/2" do
    test "succeeds with correct credentials once phone is verified" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      otp = extract_otp(user.phone_number)
      {:ok, _} = Accounts.verify_otp(user.phone_number, otp)

      assert {:ok, authenticated} = Accounts.authenticate("0712345678", "supersecret")
      assert authenticated.id == user.id
    end

    test "fails if phone is not yet verified" do
      {:ok, _user} = Accounts.register_user(@valid_attrs)

      assert {:error, :phone_not_verified} = Accounts.authenticate("0712345678", "supersecret")
    end

    test "fails with wrong password" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      otp = extract_otp(user.phone_number)
      {:ok, _} = Accounts.verify_otp(user.phone_number, otp)

      assert {:error, :invalid_credentials} = Accounts.authenticate("0712345678", "wrongpassword")
    end

    test "fails for an unregistered phone number without leaking that fact via a different error" do
      assert {:error, :invalid_credentials} = Accounts.authenticate("0799999999", "whatever1")
    end
  end

  defp extract_otp(phone_number) do
    message = Lipaharaka.SMS.Test.last_message_to(phone_number)
    [otp] = Regex.run(~r/\d{6}/, message)
    otp
  end
end
