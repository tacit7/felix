defmodule RouteWiseApi.TripsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RouteWiseApi.Trips` context.
  """

  alias RouteWiseApi.Trips

  @doc """
  Generate a trip.
  """
  def trip_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || RouteWiseApi.AccountsFixtures.user_fixture().id
    
    {:ok, trip} =
      attrs
      |> Enum.into(%{
        title: "Test Trip #{System.unique_integer([:positive])}",
        start_city: "San Francisco, CA",
        end_city: "Los Angeles, CA",
        checkpoints: %{
          "stops" => ["Palo Alto, CA", "San Jose, CA"]
        },
        route_data: %{
          "distance" => "400 miles",
          "duration" => "6 hours"
        },
        pois_data: %{
          "restaurants" => [],
          "attractions" => []
        },
        is_public: false,
        user_id: user_id
      })
      |> Trips.create_trip()

    trip
  end

  @doc """
  Generate an interest category.
  """
  def interest_category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{
        name: "test_category_#{System.unique_integer([:positive])}",
        display_name: "Test Category",
        description: "A test interest category",
        icon_name: "test-icon",
        is_active: true
      })
      |> Trips.create_interest_category()

    category
  end

  @doc """
  Generate a user interest.
  """
  def user_interest_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || RouteWiseApi.AccountsFixtures.user_fixture().id
    category = attrs[:category] || interest_category_fixture()
    
    {:ok, user_interest} =
      attrs
      |> Enum.into(%{
        user_id: user_id,
        category_id: category.id,
        priority: 1,
        is_enabled: true
      })
      |> Trips.create_user_interest()

    user_interest
  end

  @doc """
  Generate a POI.
  """
  def poi_fixture(attrs \\ %{}) do
    {:ok, poi} =
      attrs
      |> Enum.into(%{
        google_place_id: "test_place_#{System.unique_integer([:positive])}",
        name: "Test POI",
        formatted_address: "123 Test St, Test City",
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194"),
        category: "restaurant",
        rating: Decimal.new("4.5"),
        price_level: 2,
        time_from_start: "2 hours"
      })
      |> Trips.create_poi()

    poi
  end
end