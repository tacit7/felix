defmodule RouteWiseApiWeb.InterestsControllerTest do
  use RouteWiseApiWeb.ConnCase

  import RouteWiseApi.AccountsFixtures

  alias RouteWiseApi.Trips

  describe "GET /api/interests/categories" do
    test "returns list of interest categories", %{conn: conn} do
      # Seed some categories
      Trips.seed_interest_categories()

      conn = get(conn, ~p"/api/interests/categories")
      response = json_response(conn, 200)
      
      assert is_list(response["data"])
      assert length(response["data"]) > 0
      
      category = List.first(response["data"])
      assert category["name"]
      assert category["display_name"]
    end
  end

  describe "authenticated endpoints" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user)
      
      # Seed interest categories
      Trips.seed_interest_categories()
      
      %{conn: conn, user: user}
    end

    test "GET /api/interests returns empty list for user with no interests", %{conn: conn} do
      conn = get(conn, ~p"/api/interests")
      response = json_response(conn, 200)
      
      assert response["data"] == []
    end

    test "GET /api/interests returns user's interests", %{conn: conn, user: user} do
      # Create some user interests
      {:ok, _interests} = Trips.create_user_interests_from_names(["restaurants", "museums"], user.id, 1)

      conn = get(conn, ~p"/api/interests")
      response = json_response(conn, 200)
      
      assert length(response["data"]) == 2
      interest = List.first(response["data"])
      assert interest["user_id"] == user.id
      assert interest["priority"] == 1
    end

    test "POST /api/interests creates user interests from category names", %{conn: conn} do
      params = %{
        "categories" => ["restaurants", "museums"],
        "priority" => 2
      }

      conn = post(conn, ~p"/api/interests", params)
      response = json_response(conn, 201)
      
      assert length(response["data"]) == 2
      interest = List.first(response["data"])
      assert interest["priority"] == 2
    end

    test "POST /api/interests defaults to priority 1 when not specified", %{conn: conn} do
      params = %{"categories" => ["restaurants"]}

      conn = post(conn, ~p"/api/interests", params)
      response = json_response(conn, 201)
      
      interest = List.first(response["data"])
      assert interest["priority"] == 1
    end

    test "POST /api/interests returns error with invalid categories format", %{conn: conn} do
      params = %{"categories" => "not_a_list"}

      conn = post(conn, ~p"/api/interests", params)
      assert json_response(conn, 400)["error"] == "categories must be a list of category names"
    end

    test "PUT /api/interests/:id updates user's interest", %{conn: conn, user: user} do
      {:ok, [interest]} = Trips.create_user_interests_from_names(["restaurants"], user.id, 1)
      
      update_params = %{
        "interest" => %{
          "priority" => 3,
          "is_enabled" => false
        }
      }

      conn = put(conn, ~p"/api/interests/#{interest.id}", update_params)
      response = json_response(conn, 200)
      
      assert response["data"]["priority"] == 3
      assert response["data"]["is_enabled"] == false
    end

    test "PUT /api/interests/:id returns 404 for non-existent interest", %{conn: conn} do
      update_params = %{"interest" => %{"priority" => 3}}

      conn = put(conn, ~p"/api/interests/00000000-0000-0000-0000-000000000000", update_params)
      assert json_response(conn, 404)
    end

    test "DELETE /api/interests/:id deletes user's interest", %{conn: conn, user: user} do
      {:ok, [interest]} = Trips.create_user_interests_from_names(["restaurants"], user.id, 1)

      conn = delete(conn, ~p"/api/interests/#{interest.id}")
      assert response(conn, 204)
    end

    test "DELETE /api/interests/:id returns 404 for non-existent interest", %{conn: conn} do
      conn = delete(conn, ~p"/api/interests/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end
end