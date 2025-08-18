defmodule RouteWiseApi.PlacesTest do
  use RouteWiseApi.DataCase

  alias RouteWiseApi.Places
  alias RouteWiseApi.Places.Place

  @valid_attrs %{
    google_place_id: "ChIJN1t_tDeuEmsRUsoyG83frY4",
    name: "Test Restaurant",
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
  }

  @invalid_attrs %{
    google_place_id: nil,
    name: nil,
    cached_at: nil,
    latitude: 91.0,  # Invalid latitude
    longitude: 181.0  # Invalid longitude
  }

  def place_fixture(attrs \\ %{}) do
    {:ok, place} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Places.create_place()

    place
  end

  describe "places" do
    test "list_places/0 returns all places" do
      place = place_fixture()
      assert Places.list_places() == [place]
    end

    test "get_place!/1 returns the place with given id" do
      place = place_fixture()
      assert Places.get_place!(place.id) == place
    end

    test "get_place/1 returns the place with given id" do
      place = place_fixture()
      assert Places.get_place(place.id) == place
    end

    test "get_place/1 returns nil for invalid id" do
      assert Places.get_place("invalid-id") == nil
    end

    test "get_place_by_google_id/1 returns place with given google place id" do
      place = place_fixture()
      assert Places.get_place_by_google_id(place.google_place_id) == place
    end

    test "get_place_by_google_id/1 returns nil for nonexistent google place id" do
      assert Places.get_place_by_google_id("nonexistent") == nil
    end

    test "create_place/1 with valid data creates a place" do
      assert {:ok, %Place{} = place} = Places.create_place(@valid_attrs)
      assert place.google_place_id == @valid_attrs.google_place_id
      assert place.name == @valid_attrs.name
      assert place.formatted_address == @valid_attrs.formatted_address
      assert Decimal.equal?(place.latitude, @valid_attrs.latitude)
      assert Decimal.equal?(place.longitude, @valid_attrs.longitude)
      assert place.place_types == @valid_attrs.place_types
      assert Decimal.equal?(place.rating, @valid_attrs.rating)
      assert place.price_level == @valid_attrs.price_level
    end

    test "create_place/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Places.create_place(@invalid_attrs)
    end

    test "update_place/2 with valid data updates the place" do
      place = place_fixture()
      update_attrs = %{name: "Updated Restaurant", rating: Decimal.new("4.8")}

      assert {:ok, %Place{} = place} = Places.update_place(place, update_attrs)
      assert place.name == "Updated Restaurant"
      assert Decimal.equal?(place.rating, Decimal.new("4.8"))
    end

    test "update_place/2 with invalid data returns error changeset" do
      place = place_fixture()
      assert {:error, %Ecto.Changeset{}} = Places.update_place(place, @invalid_attrs)
      assert place == Places.get_place!(place.id)
    end

    test "delete_place/1 deletes the place" do
      place = place_fixture()
      assert {:ok, %Place{}} = Places.delete_place(place)
      assert_raise Ecto.NoResultsError, fn -> Places.get_place!(place.id) end
    end

    test "change_place/1 returns a place changeset" do
      place = place_fixture()
      assert %Ecto.Changeset{} = Places.change_place(place)
    end

    test "upsert_place_from_google/1 creates new place" do
      google_data = %{
        "place_id" => "new_place_id",
        "name" => "New Place",
        "formatted_address" => "456 New St",
        "geometry" => %{
          "location" => %{
            "lat" => 37.7849,
            "lng" => -122.4094
          }
        },
        "types" => ["restaurant"],
        "rating" => 4.2
      }

      assert {:ok, %Place{} = place} = Places.upsert_place_from_google(google_data)
      assert place.google_place_id == "new_place_id"
      assert place.name == "New Place"
    end

    test "upsert_place_from_google/1 updates existing place" do
      existing_place = place_fixture()
      
      updated_google_data = %{
        "place_id" => existing_place.google_place_id,
        "name" => "Updated Name",
        "formatted_address" => existing_place.formatted_address,
        "geometry" => %{
          "location" => %{
            "lat" => Decimal.to_float(existing_place.latitude),
            "lng" => Decimal.to_float(existing_place.longitude)
          }
        },
        "types" => existing_place.place_types,
        "rating" => 4.8
      }

      assert {:ok, %Place{} = updated_place} = Places.upsert_place_from_google(updated_google_data)
      assert updated_place.id == existing_place.id
      assert updated_place.name == "Updated Name"
    end

    test "search_places_near/3 finds places within radius" do
      # Create places at different locations
      place1 = place_fixture(%{
        name: "Close Restaurant",
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194")
      })
      
      place2 = place_fixture(%{
        google_place_id: "different_id",
        name: "Far Restaurant", 
        latitude: Decimal.new("40.7128"),  # New York coordinates
        longitude: Decimal.new("-74.0060")
      })

      location = %{lat: 37.7749, lng: -122.4194}
      results = Places.search_places_near(location, "restaurant", 10000)
      
      # Should find the close restaurant but not the far one
      assert length(results) == 1
      assert hd(results).id == place1.id
    end

    test "get_places_by_type/3 filters by place type" do
      restaurant = place_fixture(%{place_types: ["restaurant", "food"]})
      hotel = place_fixture(%{
        google_place_id: "hotel_id",
        name: "Test Hotel",
        place_types: ["lodging", "establishment"]
      })

      location = %{lat: 37.7749, lng: -122.4194}
      restaurants = Places.get_places_by_type(location, "restaurant", 10000)
      lodging = Places.get_places_by_type(location, "lodging", 10000)

      assert length(restaurants) == 1
      assert hd(restaurants).id == restaurant.id
      
      assert length(lodging) == 1
      assert hd(lodging).id == hotel.id
    end

    test "cleanup_old_cache/1 removes old cached places" do
      old_place = place_fixture(%{
        cached_at: DateTime.add(DateTime.utc_now(), -49 * 3600, :second)  # 49 hours ago
      })
      
      new_place = place_fixture(%{
        google_place_id: "new_place",
        cached_at: DateTime.utc_now()
      })

      assert {1, nil} = Places.cleanup_old_cache(hours: 48)
      
      # Old place should be deleted
      assert Places.get_place(old_place.id) == nil
      
      # New place should remain
      assert Places.get_place(new_place.id) != nil
    end
  end
end