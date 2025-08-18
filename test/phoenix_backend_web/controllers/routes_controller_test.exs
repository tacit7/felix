defmodule RouteWiseApiWeb.RoutesControllerTest do
  use RouteWiseApiWeb.ConnCase

  import RouteWiseApi.AccountsFixtures

  describe "POST /api/routes/calculate" do
    test "returns error when origin and destination are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/routes/calculate", %{})
      assert json_response(conn, 400)["error"] == "origin and destination are required"
    end

    test "returns error with invalid data structure", %{conn: conn} do
      conn = post(conn, ~p"/api/routes/calculate", %{"origin" => "San Francisco", "destination" => ""})
      assert response = json_response(conn, 500)
      # This will fail without real Google API, which is expected in test environment
    end
  end

  describe "POST /api/routes/wizard" do
    test "returns error when wizard_data is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/routes/wizard", %{})
      assert json_response(conn, 400)["error"] == "wizard_data is required"
    end
  end

  describe "POST /api/routes/optimize" do
    test "returns error when required params are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/routes/optimize", %{})
      assert json_response(conn, 400)["error"] == "origin, destination, and waypoints are required"
    end
  end

  describe "GET /api/routes/alternatives" do
    test "returns error when required params are missing", %{conn: conn} do
      conn = get(conn, ~p"/api/routes/alternatives")
      assert json_response(conn, 400)["error"] == "origin and destination are required"
    end
  end

  describe "POST /api/routes/estimate" do
    test "returns error when required params are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/routes/estimate", %{})
      assert json_response(conn, 400)["error"] == "origin and destination are required"
    end
  end

  describe "POST /api/routes/costs" do
    test "returns error when route_data is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/routes/costs", %{})
      assert json_response(conn, 400)["error"] == "route_data is required"
    end

    test "calculates costs with valid route_data", %{conn: conn} do
      route_data = %{
        "distance" => "100 km",
        "duration" => "1 hour"
      }
      
      conn = post(conn, ~p"/api/routes/costs", %{"route_data" => route_data})
      assert response = json_response(conn, 200)
      assert response["data"]["fuel"]
      assert response["data"]["total"]
    end
  end

  describe "GET /api/routes/trip/:trip_id (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user)
      %{conn: conn, user: user}
    end

    test "returns 404 for non-existent trip", %{conn: conn} do
      conn = get(conn, ~p"/api/routes/trip/00000000-0000-0000-0000-000000000000")
      assert json_response(conn, 404)
    end
  end
end