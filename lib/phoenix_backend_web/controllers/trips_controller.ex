defmodule RouteWiseApiWeb.TripsController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Trips
  alias RouteWiseApi.Trips.Trip
  alias RouteWiseApi.RouteService

  require Logger

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
    current_user = conn.assigns.current_user

    # Handle both wrapped (%{"trip" => data}) and unwrapped data for flexibility
    trip_params = case params do
      %{"trip" => trip_data} ->
        trip_data
      _ ->
        # If no "trip" wrapper, assume the params are the trip data directly
        # Remove any auth-related keys that shouldn't be in trip data
        Map.drop(params, ["_csrf_token", "_format"])
    end

    # Convert frontend field names to backend field names
    trip_params = trip_params
    |> map_frontend_field_names()

    trip_params = Map.put(trip_params, "user_id", current_user.id)

    with {:ok, %Trip{} = trip} <- Trips.create_trip(trip_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/trips/#{trip}")
      |> render(:show, trip: trip)
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
  POST /api/trips/explore - Create trip from explore data
  """
  def explore(conn, params) do
    current_user = conn.assigns.current_user

    case validate_explore_params(params) do
      {:ok, validated_params} ->
        with {:ok, %Trip{} = trip} <- Trips.create_explore_trip(validated_params, current_user.id) do
          conn
          |> put_status(:created)
          |> put_resp_header("location", ~p"/api/trips/#{trip}")
          |> render(:show, trip: trip)
        end

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
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

  def update(conn, params) do
    current_user = conn.assigns.current_user
    id = params["id"]

    # Handle unwrapped parameters (frontend sends data directly)
    trip_params = params
    |> Map.drop(["id", "_csrf_token", "_format"])
    |> map_frontend_field_names()

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

  defp validate_explore_params(params) do
    location = params["location"]
    discovered_place_ids = params["discovered_place_ids"] || []
    include_user_saved = params["include_user_saved"] || false
    title = params["title"]
    duration_days = params["duration_days"] || 1

    cond do
      is_nil(location) or location == "" ->
        {:error, "Location is required"}

      not is_list(discovered_place_ids) ->
        {:error, "discovered_place_ids must be an array"}

      not is_boolean(include_user_saved) ->
        {:error, "include_user_saved must be a boolean"}

      not is_nil(duration_days) and (not is_integer(duration_days) or duration_days < 1) ->
        {:error, "duration_days must be a positive integer"}

      true ->
        {:ok, %{
          location: location,
          discovered_place_ids: discovered_place_ids,
          include_user_saved: include_user_saved,
          title: title,
          duration_days: duration_days
        }}
    end
  end

  defp map_frontend_field_names(params) do
    params
    |> Map.put("trip_type", params["tripType"] || params["trip_type"])
    |> Map.delete("tripType")
    |> transform_pois_data()
  end

  defp transform_pois_data(params) do
    case params["pois_data"] do
      pois when is_list(pois) ->
        # Convert POI array to expected map structure for explore trips
        Map.put(params, "pois_data", %{
          "discovered_places" => pois,
          "created_from" => "explore"
        })
      pois when is_map(pois) ->
        # Already in correct format
        params
      _ ->
        # No POI data or invalid format
        Map.put(params, "pois_data", %{})
    end
  end

end