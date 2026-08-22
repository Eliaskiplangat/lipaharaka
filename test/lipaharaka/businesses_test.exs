defmodule Lipaharaka.BusinessesTest do
  use Lipaharaka.DataCase, async: false

  alias Lipaharaka.{Accounts, Businesses}

  setup do
    Lipaharaka.SMS.Test.clear()
    {:ok, user} = Accounts.register_user(%{"phone_number" => "0712345678", "password" => "supersecret"})
    %{user: user}
  end

  @valid_attrs %{
    "business_name" => "Jaza Traders Ltd",
    "registration_number" => "BN-2024-001",
    "kra_pin" => "A123456789Z",
    "sector" => "Retail",
    "mpesa_till_or_paybill" => "174379"
  }

  describe "create_business/2" do
    test "creates a business owned by the given user", %{user: user} do
      assert {:ok, business} = Businesses.create_business(user, @valid_attrs)
      assert business.user_id == user.id
      assert business.business_name == "Jaza Traders Ltd"
      assert business.kyc_status == "pending"
    end

    test "requires business_name", %{user: user} do
      attrs = Map.delete(@valid_attrs, "business_name")
      assert {:error, changeset} = Businesses.create_business(user, attrs)
      assert "can't be blank" in errors_on(changeset).business_name
    end

    test "validates KRA PIN format", %{user: user} do
      attrs = Map.put(@valid_attrs, "kra_pin", "not-a-pin")
      assert {:error, changeset} = Businesses.create_business(user, attrs)
      assert errors_on(changeset).kra_pin != []
    end

    test "rejects a second business for the same user", %{user: user} do
      assert {:ok, _business} = Businesses.create_business(user, @valid_attrs)
      assert {:error, :already_exists} = Businesses.create_business(user, @valid_attrs)
    end

    test "does not trust a client-supplied user_id — always uses the given user", %{user: user} do
      other_id = Ecto.UUID.generate()
      attrs = Map.put(@valid_attrs, "user_id", other_id)

      assert {:ok, business} = Businesses.create_business(user, attrs)
      assert business.user_id == user.id
      refute business.user_id == other_id
    end
  end

  describe "get_business_for_user/1" do
    test "returns nil when the user has no business", %{user: user} do
      assert Businesses.get_business_for_user(user) == nil
    end

    test "returns the user's business when one exists", %{user: user} do
      {:ok, created} = Businesses.create_business(user, @valid_attrs)
      assert %{id: id} = Businesses.get_business_for_user(user)
      assert id == created.id
    end
  end

  describe "update_business/2" do
    test "updates fields on an existing business", %{user: user} do
      {:ok, _business} = Businesses.create_business(user, @valid_attrs)

      assert {:ok, updated} = Businesses.update_business(user, %{"sector" => "Wholesale"})
      assert updated.sector == "Wholesale"
      # Unrelated fields are untouched
      assert updated.business_name == "Jaza Traders Ltd"
    end

    test "returns :not_found if the user has no business yet", %{user: user} do
      assert {:error, :not_found} = Businesses.update_business(user, %{"sector" => "Wholesale"})
    end
  end
end
