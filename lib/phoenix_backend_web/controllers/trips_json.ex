defmodule RouteWiseApiWeb.TripsJSON do
  import RouteWiseApiWeb.CacheHelpers
  alias RouteWiseApi.Trips.Trip

  @doc """
  Renders a list of trips.
  """
  def index(%{trips: trips} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: for(trip <- trips, do: data(trip))}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders a single trip.
  """
  def show(%{trip: trip} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: data(trip)}
    |> maybe_add_cache_meta(cache_info)
  end

  defp data(%Trip{} = trip) do
    %{
      # Original fields
      id: trip.id,
      title: trip.title,
      start_city: trip.start_city,
      end_city: trip.end_city,
      trip_type: trip.trip_type,
      checkpoints: trip.checkpoints || %{},
      route_data: trip.route_data || %{},
      pois_data: trip.pois_data || %{},
      is_public: trip.is_public,
      user_id: trip.user_id,
      
      # Enhanced fields
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
      last_modified_by_user_at: trip.last_modified_by_user_at,
      
      # Timestamps
      inserted_at: trip.inserted_at,
      updated_at: trip.updated_at
    }
  end
end