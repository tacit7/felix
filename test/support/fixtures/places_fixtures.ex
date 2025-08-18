defmodule RouteWiseApi.PlacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RouteWiseApi.Places` context.
  """

  alias RouteWiseApi.Places

  @doc """
  Generate a place.
  """
  def place_fixture(attrs \\ %{}) do
    {:ok, place} =
      attrs
      |> Enum.into(%{
        google_place_id: "ChIJN1t_tDeuEmsRUsoyG83frY4_#{System.unique_integer([:positive])}",
        name: "Test Restaurant #{System.unique_integer([:positive])}",
        formatted_address: "123 Test St, Test City, TC 12345",
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194"),
        place_types: ["restaurant", "food", "establishment"],
        rating: Decimal.new("4.5"),
        price_level: 2,
        phone_number: "+1-555-123-4567",
        website: "https://example.com",
        opening_hours: %{
          "open_now" => true,
          "weekday_text" => ["Monday: 9:00 AM – 10:00 PM"],
          "periods" => []
        },
        photos: [%{
          "photo_reference" => "test_photo_ref",
          "width" => 400,
          "height" => 300,
          "html_attributions" => ["Test Attribution"]
        }],
        reviews_count: 25,
        google_data: %{"test" => "data"},
        cached_at: DateTime.utc_now()
      })
      |> Places.create_place()

    place
  end

  @doc """
  Generate a google places API response for testing.
  """
  def google_places_response_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "place_id" => "ChIJN1t_tDeuEmsRUsoyG83frY4",
      "name" => "Test Restaurant",
      "formatted_address" => "123 Test St, Test City, TC 12345",
      "geometry" => %{
        "location" => %{
          "lat" => 37.7749,
          "lng" => -122.4194
        }
      },
      "types" => ["restaurant", "food", "establishment"],
      "rating" => 4.5,
      "price_level" => 2,
      "formatted_phone_number" => "+1-555-123-4567",
      "website" => "https://example.com",
      "opening_hours" => %{
        "open_now" => true,
        "weekday_text" => ["Monday: 9:00 AM – 10:00 PM"],
        "periods" => []
      },
      "photos" => [%{
        "photo_reference" => "test_photo_ref",
        "width" => 400,
        "height" => 300,
        "html_attributions" => ["Test Attribution"]
      }],
      "reviews" => [
        %{"rating" => 5, "text" => "Great food!"},
        %{"rating" => 4, "text" => "Good service"}
      ]
    })
  end
end