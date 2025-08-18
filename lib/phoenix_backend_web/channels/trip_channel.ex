defmodule RouteWiseApiWeb.TripChannel do
  use RouteWiseApiWeb, :channel
  require Logger

  alias RouteWiseApi.Trips
  alias RouteWiseApi.Accounts

  @doc """
  Join a trip channel. Users can only join their own trip channels.
  Channel format: "trip:user:<user_id>"
  """
  def join("trip:user:" <> user_id_str, _payload, socket) do
    Logger.info("Trip channel join attempt - user_id: #{user_id_str}, socket: #{socket.id}")
    
    with {user_id, ""} <- Integer.parse(user_id_str),
         %{} = current_user <- socket.assigns[:current_user],
         true <- current_user.id == user_id do
      
      Logger.info("Trip channel join successful - user_id: #{user_id}")
      {:ok, assign(socket, :user_id, user_id)}
    else
      _ ->
        Logger.warning("Trip channel join denied - unauthorized access attempt")
        {:error, %{reason: "unauthorized"}}
    end
  end

  @doc """
  Save a new trip via WebSocket
  """
  def handle_in("save_trip", trip_params, socket) do
    Logger.info("Trip save request - user_id: #{socket.assigns.user_id}")
    
    # Add user_id to params and set last_modified timestamp
    enhanced_params = trip_params
    |> Map.put("user_id", socket.assigns.user_id)
    |> Map.put("last_modified_by_user_at", DateTime.utc_now())
    
    case Trips.create_trip(enhanced_params) do
      {:ok, trip} ->
        Logger.info("Trip created successfully - trip_id: #{trip.id}")
        
        # Broadcast to user's channel for real-time updates across devices
        broadcast(socket, "trip_created", %{
          trip: format_trip_response(trip),
          user_id: socket.assigns.user_id
        })
        
        {:reply, {:ok, %{trip: format_trip_response(trip)}}, socket}
      
      {:error, changeset} ->
        Logger.warning("Trip creation failed - errors: #{inspect(changeset.errors)}")
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  end

  @doc """
  Update an existing trip via WebSocket
  """
  def handle_in("update_trip", %{"id" => trip_id, "data" => trip_params}, socket) do
    Logger.info("Trip update request - trip_id: #{trip_id}, user_id: #{socket.assigns.user_id}")
    
    with {:ok, trip} <- Trips.get_user_trip_with_error(socket.assigns.user_id, trip_id),
         enhanced_params <- Map.put(trip_params, "last_modified_by_user_at", DateTime.utc_now()),
         {:ok, updated_trip} <- Trips.update_trip(trip, enhanced_params) do
      
      Logger.info("Trip updated successfully - trip_id: #{trip_id}")
      
      # Broadcast update to user's channel
      broadcast(socket, "trip_updated", %{
        trip: format_trip_response(updated_trip),
        user_id: socket.assigns.user_id
      })
      
      {:reply, {:ok, %{trip: format_trip_response(updated_trip)}}, socket}
    else
      {:error, :not_found} ->
        Logger.warning("Trip update failed - trip not found: #{trip_id}")
        {:reply, {:error, %{message: "Trip not found"}}, socket}
      
      {:error, changeset} ->
        Logger.warning("Trip update failed - errors: #{inspect(changeset.errors)}")
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  end

  @doc """
  Delete a trip via WebSocket
  """
  def handle_in("delete_trip", %{"id" => trip_id}, socket) do
    Logger.info("Trip delete request - trip_id: #{trip_id}, user_id: #{socket.assigns.user_id}")
    
    with {:ok, trip} <- Trips.get_user_trip_with_error(socket.assigns.user_id, trip_id),
         {:ok, deleted_trip} <- Trips.delete_trip(trip) do
      
      Logger.info("Trip deleted successfully - trip_id: #{trip_id}")
      
      # Broadcast deletion to user's channel
      broadcast(socket, "trip_deleted", %{
        trip_id: trip_id,
        user_id: socket.assigns.user_id
      })
      
      {:reply, {:ok, %{message: "Trip deleted successfully", trip_id: trip_id}}, socket}
    else
      {:error, :not_found} ->
        Logger.warning("Trip deletion failed - trip not found: #{trip_id}")
        {:reply, {:error, %{message: "Trip not found"}}, socket}
      
      {:error, changeset} ->
        Logger.warning("Trip deletion failed - errors: #{inspect(changeset.errors)}")
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  end

  @doc """
  Get user's trips via WebSocket
  """
  def handle_in("get_trips", _params, socket) do
    Logger.info("Get trips request - user_id: #{socket.assigns.user_id}")
    
    trips = Trips.list_user_trips(socket.assigns.user_id)
    formatted_trips = Enum.map(trips, &format_trip_response/1)
    
    {:reply, {:ok, %{trips: formatted_trips}}, socket}
  end

  @doc """
  Get a specific trip via WebSocket
  """
  def handle_in("get_trip", %{"id" => trip_id}, socket) do
    Logger.info("Get trip request - trip_id: #{trip_id}, user_id: #{socket.assigns.user_id}")
    
    case Trips.get_user_trip_with_error(socket.assigns.user_id, trip_id) do
      {:ok, trip} ->
        {:reply, {:ok, %{trip: format_trip_response(trip)}}, socket}
      
      {:error, :not_found} ->
        {:reply, {:error, %{message: "Trip not found"}}, socket}
    end
  end

  @doc """
  Add activity to a specific day via WebSocket
  """
  def handle_in("add_activity", %{"trip_id" => trip_id, "day_index" => day_index, "activity" => activity}, socket) do
    Logger.info("Add activity request - trip_id: #{trip_id}, day: #{day_index}")
    
    with {:ok, trip} <- Trips.get_user_trip(socket.assigns.user_id, trip_id) do
      # Use the activity management helper from Trip schema
      updated_trip = RouteWiseApi.Trips.Trip.add_activity_to_day(trip, day_index, activity)
      
      case Trips.update_trip(trip, %{days: updated_trip.days, last_modified_by_user_at: DateTime.utc_now()}) do
        {:ok, saved_trip} ->
          broadcast(socket, "activity_added", %{
            trip_id: trip_id,
            day_index: day_index,
            activity: activity,
            trip: format_trip_response(saved_trip)
          })
          
          {:reply, {:ok, %{trip: format_trip_response(saved_trip)}}, socket}
        
        {:error, changeset} ->
          {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
      end
    else
      {:error, :not_found} ->
        {:reply, {:error, %{message: "Trip not found"}}, socket}
    end
  end

  # Private helper functions

  defp format_trip_response(trip) do
    %{
      id: trip.id,
      title: trip.title,
      start_city: trip.start_city,
      end_city: trip.end_city,
      trip_type: trip.trip_type,
      start_date: trip.start_date,
      end_date: trip.end_date,
      start_location: trip.start_location || %{},
      end_location: trip.end_location || %{},
      days: trip.days || %{"days" => []},
      total_distance_km: trip.total_distance_km,
      estimated_cost: trip.estimated_cost,
      difficulty_level: trip.difficulty_level,
      trip_tags: trip.trip_tags || [],
      weather_requirements: trip.weather_requirements || %{},
      packing_list: trip.packing_list || [],
      status: trip.status,
      is_public: trip.is_public,
      checkpoints: trip.checkpoints || %{},
      route_data: trip.route_data || %{},
      pois_data: trip.pois_data || %{},
      last_modified_by_user_at: trip.last_modified_by_user_at,
      inserted_at: trip.inserted_at,
      updated_at: trip.updated_at
    }
  end

  defp format_changeset_errors(changeset) do
    Enum.map(changeset.errors, fn {field, {message, _}} ->
      %{field: field, message: message}
    end)
  end
end