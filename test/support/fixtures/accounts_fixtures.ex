defmodule RouteWiseApi.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RouteWiseApi.Accounts` context.
  """

  alias RouteWiseApi.Accounts

  @doc """
  Generate a unique username.
  """
  def unique_username, do: "user#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique email.
  """
  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        username: unique_username(),
        email: unique_email(),
        password: "Test123!@#",
        full_name: "Test User",
        provider: "local"
      })
      |> Accounts.register_user()

    user
  end

  @doc """
  Generate a Google OAuth user.
  """
  def google_user_fixture(attrs \\ %{}) do
    google_data = %{
      "sub" => "google_id_#{System.unique_integer([:positive])}",
      "email" => unique_email(),
      "name" => "Google User",
      "picture" => "https://example.com/avatar.jpg"
    }

    {:ok, user} = 
      attrs
      |> Enum.into(google_data)
      |> Accounts.find_or_create_user_from_google()

    user
  end

  @doc """
  Generate a valid user token for authentication.
  """
  def user_token_fixture(user \\ nil) do
    user = user || user_fixture()
    Accounts.generate_user_session_token(user)
  end
end