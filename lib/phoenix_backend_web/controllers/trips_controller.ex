defmodule RouteWiseApiWeb.TripsController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Trips
  alias RouteWiseApi.Trips.Trip
  alias RouteWiseApi.RouteService

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  GET /api/trips - List user's trips (requires authentication)
  """
  def index(conn, _params) do
    current_user = conn.assigns.current_user
    trips = Trips.list_user_trips(current_user.id)
    render(conn, :index, trips: trips)
  end

  @doc """
  GET /api/trips/public - List public trips
  """
  def public(conn, _params) do
    trips = Trips.list_public_trips()
    render(conn, :index, trips: trips)
  end

  @doc """
  POST /api/trips - Create a new trip (requires authentication)
  """
  def create(conn, params) do
    case params do
      %{"trip" => trip_params} ->
        current_user = conn.assigns.current_user
        trip_params = Map.put(trip_params, "user_id", current_user.id)

        with {:ok, %Trip{} = trip} <- Trips.create_trip(trip_params) do
          conn
          |> put_status(:created)
          |> put_resp_header("location", ~p"/api/trips/#{trip}")
          |> render(:show, trip: trip)
        end
        
      _ ->
        Logger.error("🚨 Expected 'trip' key in params, got: #{inspect(Map.keys(params))}")
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Expected 'trip' key in request body", received_keys: Map.keys(params)})
    end
  end

  @doc """
  POST /api/trips/from_wizard - Create trip from wizard data
  """
  def create_from_wizard(conn, %{"wizard_data" => wizard_data} = params) do
    current_user = conn.assigns.current_user
    calculate_route = Map.get(params, "calculate_route", true)

    with {:ok, %Trip{} = trip} <- Trips.create_trip_from_wizard(wizard_data, current_user.id),
         {:ok, updated_trip} <- maybe_calculate_route(trip, wizard_data, calculate_route) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/trips/#{trip}")
      |> render(:show, trip: updated_trip)
    end
  end

  @doc """
  GET /api/trips/:id - Show a specific trip
  """
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    
    # If user is authenticated, check if they own the trip first
    case current_user do
      %{id: user_id} ->
        case Trips.get_user_trip(id, user_id) do
          nil -> 
            # Not user's trip, check if it's public
            case Trips.get_trip(id) do
              %Trip{is_public: true} = trip -> render(conn, :show, trip: trip)
              %Trip{is_public: false} -> {:error, :not_found}
              nil -> {:error, :not_found}
            end
          trip ->
            render(conn, :show, trip: trip)
        end
      nil ->
        # Not authenticated, only show public trips
        case Trips.get_trip(id) do
          %Trip{is_public: true} = trip -> render(conn, :show, trip: trip)
          %Trip{is_public: false} -> {:error, :not_found}
          nil -> {:error, :not_found}
        end
    end
  end

  @doc """
  PUT /api/trips/:id - Update a trip
  """
  def update(conn, %{"id" => id, "trip" => trip_params}) do
    current_user = conn.assigns.current_user
    
    case Trips.get_user_trip(id, current_user.id) do
      nil -> {:error, :not_found}
      trip ->
        with {:ok, %Trip{} = trip} <- Trips.update_trip(trip, trip_params) do
          render(conn, :show, trip: trip)
        end
    end
  end

  @doc """
  DELETE /api/trips/:id - Delete a trip
  """
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    
    case Trips.get_user_trip(id, current_user.id) do
      nil -> {:error, :not_found}
      trip ->
        with {:ok, %Trip{}} <- Trips.delete_trip(trip) do
          send_resp(conn, :no_content, "")
        end
    end
  end

  # Private helper functions

  defp maybe_calculate_route(trip, wizard_data, true) do
    case RouteService.calculate_route_from_wizard_data(wizard_data) do
      {:ok, route_data} ->
        Trips.update_trip(trip, %{route_data: route_data})
      
      {:error, reason} ->
        # Log the error but don't fail trip creation
        require Logger
        Logger.warning("Failed to calculate route for trip #{trip.id}: #{inspect(reason)}")
        {:ok, trip}
    end
  end

  defp maybe_calculate_route(trip, _wizard_data, false) do
    {:ok, trip}
  end

end