defmodule LipaharakaWeb.Auth.TokenTest do
  use ExUnit.Case, async: true

  alias LipaharakaWeb.Auth.Token

  @user_id "1a2b3c4d-1111-2222-3333-444455556666"

  test "signs and verifies a round trip successfully" do
    token = Token.sign(@user_id)
    assert {:ok, @user_id} = Token.verify(token)
  end

  test "rejects a garbage token" do
    assert {:error, :invalid} = Token.verify("not-a-real-token")
  end

  test "rejects a missing token" do
    assert {:error, :missing} = Token.verify(nil)
  end

  test "rejects an expired token" do

    thirty_one_days_ago = System.system_time(:second) - 31 * 24 * 60 * 60
    token = Token.sign(@user_id, signed_at: thirty_one_days_ago)

    assert {:error, :expired} = Token.verify(token)
  end

  test "a token signed for one user doesn't verify as a different user" do
    token = Token.sign(@user_id)
    assert {:ok, verified_id} = Token.verify(token)
    refute verified_id == "some-other-user-id"
  end
end
