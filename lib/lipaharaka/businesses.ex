defmodule Lipaharaka.Businesses do
  @moduledoc """
  The Businesses context: SME business profile creation and management.

  As with Accounts, controllers should call into this module rather
  than touching `Lipaharaka.Businesses.Business`/`Repo` directly.

  Every function here that could act on a business takes the
  authenticated `Lipaharaka.Accounts.User` (or its id) explicitly, and
  scopes queries to it — there is no function in this module that
  fetches "a business by business id" alone, on purpose. That would
  make it too easy for a future controller to accidentally let one
  user look up or modify another user's business. If/when we build
  Admin review (FR-1.4) and genuinely need "any business by id",
  that'll be a deliberately separate, clearly-named function such as
  `get_business_for_admin/1` — not a reuse of this one.
  """

  import Ecto.Query, warn: false

  alias Lipaharaka.Repo
  alias Lipaharaka.Accounts.User
  alias Lipaharaka.Businesses.Business

  @doc """
  Creates a business owned by the given user.

  Returns `{:error, :already_exists}` if the user already has a
  business (see the one-business-per-user constraint), or
  `{:error, changeset}` for other validation failures.
  """
  @spec create_business(User.t(), map()) ::
          {:ok, Business.t()} | {:error, :already_exists | Ecto.Changeset.t()}
  def create_business(%User{} = user, attrs) do
    changeset =
      %Business{user_id: user.id}
      |> Business.create_changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, business} ->
        {:ok, business}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if Keyword.has_key?(errors, :user_id) do
          {:error, :already_exists}
        else
          {:error, changeset}
        end
    end
  end

  @doc "Fetches the given user's business, or `nil` if they haven't registered one."
  @spec get_business_for_user(User.t()) :: Business.t() | nil
  def get_business_for_user(%User{} = user) do
    Repo.get_by(Business, user_id: user.id)
  end

  @doc """
  Updates the given user's business profile.

  Returns `{:error, :not_found}` if they don't have a business yet,
  or `{:error, changeset}` for validation failures.
  """
  @spec update_business(User.t(), map()) ::
          {:ok, Business.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_business(%User{} = user, attrs) do
    case get_business_for_user(user) do
      nil ->
        {:error, :not_found}

      business ->
        business
        |> Business.update_changeset(attrs)
        |> Repo.update()
    end
  end
end
