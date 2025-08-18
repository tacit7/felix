defmodule RouteWiseApiWeb.PlacesControllerTest do
  use RouteWiseApiWeb.ConnCase

  import RouteWiseApi.PlacesFixtures

  describe "GET /api/places/search" do
    test "returns 400 when query is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/places/search?lat=37.7749&lng=-122.4194")
      assert json_response(conn, 400)
    end

    test "returns 400 when location is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/places/search?query=restaurants")
      assert json_response(conn, 400)
    end

    test "returns 400 when coordinates are invalid", %{conn: conn} do
      conn = get(conn, ~p"/api/places/search?query=restaurants&lat=invalid&lng=-122.4194")
      assert json_response(conn, 400)
    end

    test "returns search results with valid params", %{conn: conn} do
      # Create a test place in the database
      place = place_fixture(%{
        name: "Test Restaurant",
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194")
      })

      conn = get(conn, ~p"/api/places/search?query=restaurant&lat=37.7749&lng=-122.4194")
      assert %{
        "status" => "success",
        "data" => %{
          "places" => places,
          "count" => count
        }
      } = json_response(conn, 200)

      assert is_list(places)
      assert is_integer(count)
    end
  end

  describe "GET /api/places/details/:id" do
    test "returns place details for valid google place id", %{conn: conn} do
      place = place_fixture()
      
      conn = get(conn, ~p"/api/places/details/#{place.google_place_id}")
      assert %{
        "status" => "success",
        "data" => %{
          "place" => place_data
        }
      } = json_response(conn, 200)

      assert place_data["google_place_id"] == place.google_place_id
      assert place_data["name"] == place.name
      assert is_map(place_data["location"])
    end
  end

  describe "GET /api/places/autocomplete" do
    test "returns 400 when input is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/places/autocomplete")
      assert json_response(conn, 400)
    end

    test "returns autocomplete structure with valid input", %{conn: conn} do
      conn = get(conn, ~p"/api/places/autocomplete?input=San Franc")
      assert %{
        "status" => "success",
        "data" => %{
          "suggestions" => suggestions,
          "count" => count
        }
      } = json_response(conn, 200)

      assert is_list(suggestions)
      assert is_integer(count)
    end
  end

  describe "GET /api/places/nearby" do
    test "returns 400 when type is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/places/nearby?lat=37.7749&lng=-122.4194")
      assert json_response(conn, 400)
    end

    test "returns 400 when location is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/places/nearby?type=restaurant")
      assert json_response(conn, 400)
    end

    test "returns nearby places with valid params", %{conn: conn} do
      place = place_fixture(%{
        place_types: ["restaurant", "food"],
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194")
      })

      conn = get(conn, ~p"/api/places/nearby?type=restaurant&lat=37.7749&lng=-122.4194")
      assert %{
        "status" => "success",
        "data" => %{
          "places" => places,
          "count" => count
        }
      } = json_response(conn, 200)

      assert is_list(places)
      assert is_integer(count)
    end
  end

  describe "GET /api/places/photo" do
    test "returns 400 when photo_reference is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/places/photo")
      assert json_response(conn, 400)
    end

    test "returns photo URL with valid photo_reference", %{conn: conn} do
      conn = get(conn, ~p"/api/places/photo?photo_reference=test_ref&maxwidth=400")
      assert %{
        "status" => "success",
        "data" => %{
          "photo_url" => photo_url
        }
      } = json_response(conn, 200)

      assert is_binary(photo_url)
      assert String.contains?(photo_url, "photo_reference=test_ref")
    end
  end
end