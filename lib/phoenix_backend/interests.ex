defmodule RouteWiseApi.Interests do
  @moduledoc """
  The Interests context - handles interest categories and user interests.
  This is a convenience module that delegates to the Trips context.
  """

  alias RouteWiseApi.Trips

  @doc """
  Returns the list of interest categories.
  """
  def list_interest_categories do
    Trips.list_interest_categories()
  end

  @doc """
  Gets a single interest category.
  """
  def get_interest_category!(id), do: Trips.get_interest_category!(id)

  @doc """
  Gets an interest category by name.
  """
  def get_interest_category_by_name(name) do
    Trips.get_interest_category_by_name(name)
  end

  @doc """
  Creates an interest category.
  """
  def create_interest_category(attrs \\ %{}) do
    Trips.create_interest_category(attrs)
  end

  @doc """
  Updates an interest category.
  """
  def update_interest_category(interest_category, attrs) do
    Trips.update_interest_category(interest_category, attrs)
  end

  @doc """
  Deletes an interest category.
  """
  def delete_interest_category(interest_category) do
    Trips.delete_interest_category(interest_category)
  end

  @doc """
  Returns the list of user interests for a specific user.
  """
  def get_user_interests(user_id) do
    Trips.get_user_interests(user_id)
  end

  @doc """
  Creates a user interest.
  """
  def create_user_interest(attrs \\ %{}) do
    Trips.create_user_interest(attrs)
  end

  @doc """
  Updates a user interest.
  """
  def update_user_interest(user_interest, attrs) do
    Trips.update_user_interest(user_interest, attrs)
  end

  @doc """
  Deletes a user interest.
  """
  def delete_user_interest(user_interest) do
    Trips.delete_user_interest(user_interest)
  end
end