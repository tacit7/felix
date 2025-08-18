defmodule RouteWiseApiWeb.TripsControllerTest do
  use RouteWiseApiWeb.ConnCase

  import RouteWiseApi.{AccountsFixtures, TripsFixtures}

  alias RouteWiseApi.Trips.Trip

  describe "GET /api/trips/public" do
    test "returns list of public trips", %{conn: conn} do
      user = user_fixture()
      _private_trip = trip_fixture(user_id: user.id, is_public: false)
      public_trip = trip_fixture(user_id: user.id, is_public: true)

      conn = get(conn, ~p"/api/trips/public")
      response = json_response(conn, 200)
      
      assert length(response["data"]) == 1
      assert List.first(response["data"])["id"] == public_trip.id
    end
  end

  describe "authenticated endpoints" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user)
      %{conn: conn, user: user}
    end

    test "GET /api/trips returns user's trips", %{conn: conn, user: user} do
      trip1 = trip_fixture(user_id: user.id)
      trip2 = trip_fixture(user_id: user.id)
      _other_user_trip = trip_fixture(user_id: user_fixture().id)

      conn = get(conn, ~p"/api/trips")
      response = json_response(conn, 200)
      
      assert length(response["data"]) == 2
      trip_ids = Enum.map(response["data"], & &1["id"])
      assert trip1.id in trip_ids
      assert trip2.id in trip_ids
    end

    test "POST /api/trips creates trip with valid data", %{conn: conn} do
      trip_params = %{
        "trip" => %{
          "title" => "Test Trip",
          "start_city" => "San Francisco, CA",
          "end_city" => "Los Angeles, CA",
          "is_public" => false
        }
      }

      conn = post(conn, ~p"/api/trips", trip_params)
      response = json_response(conn, 201)
      
      assert response["data"]["title"] == "Test Trip"
      assert response["data"]["start_city"] == "San Francisco, CA"
      assert response["data"]["end_city"] == "Los Angeles, CA"
      assert response["data"]["is_public"] == false
    end

    test "POST /api/trips returns errors with invalid data", %{conn: conn} do
      trip_params = %{"trip" => %{"title" => ""}}

      conn = post(conn, ~p"/api/trips", trip_params)
      assert json_response(conn, 422)["errors"]
    end

    test "POST /api/trips/from_wizard creates trip from wizard data", %{conn: conn} do
      wizard_data = %{
        "title" => "Wizard Trip",
        "startLocation" => %{"description" => "San Francisco, CA"},
        "endLocation" => %{"description" => "Los Angeles, CA"},
        "stops" => ["Palo Alto, CA"],
        "interests" => ["restaurants", "museums"]
      }

      params = %{
        "wizard_data" => wizard_data,
        "calculate_route" => false  # Don't calculate route to avoid API calls
      }

      conn = post(conn, ~p"/api/trips/from_wizard", params)
      response = json_response(conn, 201)
      
      assert response["data"]["title"] == "Wizard Trip"
      assert response["data"]["start_city"] == "San Francisco, CA"
      assert response["data"]["end_city"] == "Los Angeles, CA"
    end

    test "GET /api/trips/:id returns user's trip", %{conn: conn, user: user} do
      trip = trip_fixture(user_id: user.id)

      conn = get(conn, ~p"/api/trips/#{trip.id}")
      response = json_response(conn, 200)
      
      assert response["data"]["id"] == trip.id
      assert response["data"]["title"] == trip.title
    end

    test "GET /api/trips/:id returns 404 for non-existent trip", %{conn: conn} do
      conn = get(conn, ~p"/api/trips/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end

    test "GET /api/trips/:id returns 404 for other user's private trip", %{conn: conn} do
      other_user = user_fixture()
      trip = trip_fixture(user_id: other_user.id, is_public: false)

      conn = get(conn, ~p"/api/trips/#{trip.id}")
      assert json_response(conn, 404)
    end

    test "GET /api/trips/:id returns public trip from other user", %{conn: conn} do
      other_user = user_fixture()
      trip = trip_fixture(user_id: other_user.id, is_public: true)

      conn = get(conn, ~p"/api/trips/#{trip.id}")
      response = json_response(conn, 200)
      
      assert response["data"]["id"] == trip.id
    end

    test "PUT /api/trips/:id updates user's trip", %{conn: conn, user: user} do
      trip = trip_fixture(user_id: user.id)
      update_params = %{
        "trip" => %{
          "title" => "Updated Trip Title",
          "is_public" => true
        }
      }

      conn = put(conn, ~p"/api/trips/#{trip.id}", update_params)
      response = json_response(conn, 200)
      
      assert response["data"]["title"] == "Updated Trip Title"
      assert response["data"]["is_public"] == true
    end

    test "PUT /api/trips/:id returns 404 for other user's trip", %{conn: conn} do
      other_user = user_fixture()
      trip = trip_fixture(user_id: other_user.id)
      update_params = %{"trip" => %{"title" => "Hacked"}}

      conn = put(conn, ~p"/api/trips/#{trip.id}", update_params)
      assert json_response(conn, 404)
    end

    test "DELETE /api/trips/:id deletes user's trip", %{conn: conn, user: user} do
      trip = trip_fixture(user_id: user.id)

      conn = delete(conn, ~p"/api/trips/#{trip.id}")
      assert response(conn, 204)
    end

    test "DELETE /api/trips/:id returns 404 for other user's trip", %{conn: conn} do
      other_user = user_fixture()
      trip = trip_fixture(user_id: other_user.id)

      conn = delete(conn, ~p"/api/trips/#{trip.id}")
      assert json_response(conn, 404)
    end
  end
end