defmodule RouteWiseApi.Trips do
  @moduledoc """
  The Trips context - handles trip management, user interests, and POIs.
  """

  import Ecto.Query, warn: false
  alias RouteWiseApi.Repo

  alias RouteWiseApi.Trips.{Trip, InterestCategory, UserInterest, POI, TripCollaborator, TripActivity}

  require Logger

  # Trip CRUD operations

  @doc """
  Returns the list of trips.
  """
  def list_trips do
    Repo.all(Trip)
  end

  @doc """
  Returns the list of trips for a specific user.
  """
  def list_user_trips(user_id) do
    Trip
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.updated_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of public trips.
  """
  def list_public_trips do
    Trip
    |> where([t], t.is_public == true)
    |> order_by([t], desc: t.updated_at)
    |> Repo.all()
  end

  @doc """
  Gets a single trip.
  """
  def get_trip!(id), do: Repo.get!(Trip, id)

  @doc """
  Gets a single trip.
  """
  def get_trip(id), do: Repo.get(Trip, id)

  @doc """
  Gets a trip by ID and user ID (for authorization).
  Returns the trip struct or nil.
  """
  def get_user_trip(id, user_id) do
    Trip
    |> where([t], t.id == ^id and t.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Gets a trip by user ID and trip ID with error handling for TripChannel.
  Returns {:ok, trip} or {:error, :not_found}.
  """
  def get_user_trip_with_error(user_id, trip_id) do
    case get_user_trip(trip_id, user_id) do
      nil -> {:error, :not_found}
      trip -> {:ok, trip}
    end
  end

  @doc """
  Creates a trip.
  """
  def create_trip(attrs \\ %{}) do
    %Trip{}
    |> Trip.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a trip from trip wizard data.
  """
  def create_trip_from_wizard(wizard_data, user_id) do
    attrs = Trip.from_wizard_data(wizard_data, user_id)
    create_trip(attrs)
  end

  @doc """
  Updates a trip.
  """
  def update_trip(%Trip{} = trip, attrs) do
    trip
    |> Trip.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trip.
  """
  def delete_trip(%Trip{} = trip) do
    Repo.delete(trip)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trip changes.
  """
  def change_trip(%Trip{} = trip, attrs \\ %{}) do
    Trip.changeset(trip, attrs)
  end

  # Interest Category operations

  @doc """
  Returns the list of interest categories.
  """
  def list_interest_categories do
    InterestCategory
    |> where([ic], ic.is_active == true)
    |> order_by([ic], asc: ic.display_name)
    |> Repo.all()
  end

  @doc """
  Gets a single interest category.
  """
  def get_interest_category!(id), do: Repo.get!(InterestCategory, id)

  @doc """
  Gets an interest category by name.
  """
  def get_interest_category_by_name(name) do
    Repo.get_by(InterestCategory, name: name)
  end

  @doc """
  Creates an interest category.
  """
  def create_interest_category(attrs \\ %{}) do
    %InterestCategory{}
    |> InterestCategory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an interest category.
  """
  def update_interest_category(%InterestCategory{} = interest_category, attrs) do
    interest_category
    |> InterestCategory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an interest category.
  """
  def delete_interest_category(%InterestCategory{} = interest_category) do
    Repo.delete(interest_category)
  end

  @doc """
  Seeds the database with default interest categories.
  """
  def seed_interest_categories do
    categories = InterestCategory.default_categories()
    
    Enum.each(categories, fn category_attrs ->
      case get_interest_category_by_name(category_attrs.name) do
        nil -> create_interest_category(category_attrs)
        _existing -> :ok
      end
    end)
  end

  # User Interest operations

  @doc """
  Returns the list of user interests for a specific user.
  """
  def list_user_interests(user_id) do
    UserInterest
    |> where([ui], ui.user_id == ^user_id)
    |> join(:inner, [ui], ic in InterestCategory, on: ui.category_id == ic.id)
    |> select([ui, ic], %{ui | category: ic})
    |> order_by([ui], desc: ui.priority, asc: ui.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single user interest.
  """
  def get_user_interest!(id), do: Repo.get!(UserInterest, id)

  @doc """
  Gets a user interest by user and category.
  """
  def get_user_interest(user_id, category_id) do
    UserInterest
    |> where([ui], ui.user_id == ^user_id and ui.category_id == ^category_id)
    |> Repo.one()
  end

  @doc """
  Creates a user interest.
  """
  def create_user_interest(attrs \\ %{}) do
    %UserInterest{}
    |> UserInterest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates user interests from category names.
  """
  def create_user_interests_from_names(category_names, user_id, priority \\ 1) do
    results = 
      Enum.map(category_names, fn category_name ->
        case get_interest_category_by_name(category_name) do
          nil -> {:error, "Category '#{category_name}' not found"}
          category ->
            create_user_interest(%{
              user_id: user_id,
              category_id: category.id,
              priority: priority,
              is_enabled: true
            })
        end
      end)

    # Return success if all succeeded, otherwise return errors
    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      {:ok, Enum.map(results, fn {:ok, user_interest} -> user_interest end)}
    else
      errors = Enum.filter(results, fn {status, _} -> status == :error end)
      {:error, errors}
    end
  end

  @doc """
  Updates a user interest.
  """
  def update_user_interest(%UserInterest{} = user_interest, attrs) do
    user_interest
    |> UserInterest.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user interest.
  """
  def delete_user_interest(%UserInterest{} = user_interest) do
    Repo.delete(user_interest)
  end

  # POI operations

  @doc """
  Returns the list of POIs.
  """
  def list_pois do
    Repo.all(POI)
  end

  @doc """
  Returns the list of POIs by category.
  """
  def list_pois_by_category(category) do
    POI
    |> where([p], p.category == ^category)
    |> order_by([p], desc: p.rating)
    |> Repo.all()
  end

  @doc """
  Gets a single POI.
  """
  def get_poi!(id), do: Repo.get!(POI, id)

  @doc """
  Gets a single POI.
  """
  def get_poi(id), do: Repo.get(POI, id)

  @doc """
  Creates a POI.
  """
  def create_poi(attrs \\ %{}) do
    %POI{}
    |> POI.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a POI from Google Places data.
  """
  def create_poi_from_google_place(place_data, time_from_start \\ "0 hours") do
    attrs = POI.from_google_place(place_data, time_from_start)
    create_poi(attrs)
  end

  @doc """
  Updates a POI.
  """
  def update_poi(%POI{} = poi, attrs) do
    poi
    |> POI.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a POI.
  """
  def delete_poi(%POI{} = poi) do
    Repo.delete(poi)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking POI changes.
  """
  def change_poi(%POI{} = poi, attrs \\ %{}) do
    POI.changeset(poi, attrs)
  end

  @doc """
  Returns POIs for a route between two cities.
  For now, returns all POIs - can be enhanced with geographic filtering later.
  """
  def list_pois_for_route(start_city, end_city) do
    try do
      # Get coordinates for start and end cities using LocationIQ
      with {:ok, start_coords} <- get_city_coordinates(start_city),
           {:ok, end_coords} <- get_city_coordinates(end_city) do
        
        # Calculate midpoint between cities for POI search
        midpoint = calculate_midpoint(start_coords, end_coords)
        
        # Search radius based on distance between cities (min 10km, max 50km)
        distance = calculate_distance(start_coords, end_coords)
        search_radius = min(max(trunc(distance / 4), 10_000), 50_000)
        
        Logger.info("Searching POIs between #{start_city} and #{end_city}, midpoint: #{inspect(midpoint)}, radius: #{search_radius}m")
        
        # Search for multiple types of POIs along the route
        poi_types = ["restaurant", "tourist_attraction", "gas_station", "lodging", "shopping_mall"]
        
        # Collect POIs from multiple searches
        all_pois = 
          poi_types
          |> Enum.flat_map(fn poi_type ->
            case RouteWiseApi.PlacesService.find_places_by_type(midpoint, poi_type, radius: search_radius) do
              {:ok, places} -> 
                Logger.debug("Found #{length(places)} #{poi_type}s")
                places
              {:error, _reason} -> 
                Logger.warning("Failed to fetch #{poi_type}s via API, trying database fallback")
                []
              # Handle circuit breaker fallback pattern: {:error, reason, fallback_result}
              {:error, _api_error, {:ok, fallback_places}} when is_list(fallback_places) ->
                Logger.warning("Circuit breaker fallback for #{poi_type}s: using #{length(fallback_places)} fallback places")
                fallback_places
              {:error, _api_error, fallback_result} ->
                Logger.warning("Circuit breaker fallback for #{poi_type}s: #{inspect(fallback_result)}")
                case fallback_result do
                  {:ok, places} when is_list(places) -> places
                  _ -> []
                end
              # Handle any other error pattern
              _ -> 
                Logger.warning("Unhandled response for #{poi_type}s, skipping")
                []
            end
          end)
          |> Enum.uniq_by(& &1.google_place_id)  # Remove duplicates
          |> Enum.sort_by(& &1.rating, :desc)     # Sort by rating
          |> Enum.take(15)                        # Limit to 15 best POIs
        
        # If API calls failed and we have no POIs, fall back to database search around route
        final_pois = if Enum.empty?(all_pois) do
          Logger.info("🔄 API calls failed, falling back to database POIs around route")
          fallback_database_pois(start_coords, end_coords)
        else
          all_pois
        end
        
        {:ok, final_pois}
      else
        {:error, reason} ->
          Logger.error("Failed to get coordinates for route POIs: #{reason}")
          # Return empty list instead of unrelated database POIs
          {:ok, []}
      end
    rescue
      error ->
        Logger.error("Exception in list_pois_for_route: #{Exception.message(error)}")
        # Return empty list instead of unrelated database POIs
        {:ok, []}
    end
  end

  # Additional functions for dashboard

  @doc """
  Returns the count of trips for a specific user.
  """
  def count_user_trips(user_id) do
    Trip
    |> where([t], t.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns the list of user interests for a specific user.
  Alias for compatibility with dashboard controller.
  """
  def get_user_interests(user_id) do
    list_user_interests(user_id)
  end

  # Private helper functions for POI route calculations

  defp get_city_coordinates(city_name) do
    # Use LocationIQ to get coordinates for city
    case RouteWiseApi.LocationIQ.autocomplete_cities(city_name, limit: 1) do
      {:ok, [city | _]} ->
        # LocationIQ returns :lat and :lon, but we need to handle both possible field names
        lat = Map.get(city, :lat) || Map.get(city, :latitude)
        lng = Map.get(city, :lon) || Map.get(city, :longitude)
        {:ok, %{lat: lat, lng: lng}}
      {:ok, []} ->
        {:error, "City not found: #{city_name}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_midpoint(%{lat: lat1, lng: lng1}, %{lat: lat2, lng: lng2}) do
    %{
      lat: (lat1 + lat2) / 2,
      lng: (lng1 + lng2) / 2
    }
  end

  defp calculate_distance(%{lat: lat1, lng: lng1}, %{lat: lat2, lng: lng2}) do
    # Haversine formula to calculate distance in meters
    dlat = :math.pi() * (lat2 - lat1) / 180
    dlng = :math.pi() * (lng2 - lng1) / 180

    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(:math.pi() * lat1 / 180) * :math.cos(:math.pi() * lat2 / 180) *
        :math.sin(dlng / 2) * :math.sin(dlng / 2)
    
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    
    # Earth's radius in meters
    6_371_000 * c
  end

  defp fallback_database_pois(start_coords, end_coords) do
    # Create a bounding box around the entire route
    min_lat = min(start_coords.lat, end_coords.lat) - 0.2  # Add ~22km buffer
    max_lat = max(start_coords.lat, end_coords.lat) + 0.2
    min_lng = min(start_coords.lng, end_coords.lng) - 0.2
    max_lng = max(start_coords.lng, end_coords.lng) + 0.2
    
    Logger.info("🔍 Searching database POIs in bounds: lat #{min_lat}-#{max_lat}, lng #{min_lng}-#{max_lng}")
    
    # Query database for POIs in the route area
    import Ecto.Query
    alias RouteWiseApi.Places.Place
    
    query = from p in Place,
      where: p.latitude >= ^Decimal.new(to_string(min_lat)) and 
             p.latitude <= ^Decimal.new(to_string(max_lat)) and
             p.longitude >= ^Decimal.new(to_string(min_lng)) and 
             p.longitude <= ^Decimal.new(to_string(max_lng)),
      order_by: [desc: p.rating, desc: p.reviews_count],
      limit: 20
    
    places = Repo.all(query)
    Logger.info("✅ Found #{length(places)} database POIs for route fallback")
    
    places
  end

  # Trip sharing functions

  @doc """
  Get a trip by its share token.
  """
  def get_trip_by_share_token(share_token) do
    Repo.get_by(Trip, share_token: share_token)
  end

  @doc """
  List collaborators for a trip.
  """
  def list_trip_collaborators(trip_id) do
    from(c in TripCollaborator,
      where: c.trip_id == ^trip_id,
      preload: [:user, :invited_by],
      order_by: [asc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Get a specific collaborator.
  """
  def get_trip_collaborator(id) do
    TripCollaborator
    |> Repo.get(id)
    |> Repo.preload([:user, :trip])
  end

  @doc """
  Accept a collaboration invitation.
  """
  def accept_collaboration_invitation(collaborator_id, user_id) do
    with {:ok, collaborator} <- get_collaborator_for_user(collaborator_id, user_id),
         {:ok, updated_collaborator} <- update_collaboration_status(collaborator, "accepted") do
      {:ok, updated_collaborator}
    end
  end

  @doc """
  Reject a collaboration invitation.
  """
  def reject_collaboration_invitation(collaborator_id, user_id) do
    with {:ok, collaborator} <- get_collaborator_for_user(collaborator_id, user_id),
         {:ok, updated_collaborator} <- update_collaboration_status(collaborator, "rejected") do
      {:ok, updated_collaborator}
    end
  end

  @doc """
  Check if user can edit a trip.
  """
  def can_edit_trip?(trip, user_id) do
    cond do
      trip.user_id == user_id -> true
      trip.allow_public_edit and Trip.sharing_valid?(trip) -> true
      has_edit_permission?(trip.id, user_id) -> true
      true -> false
    end
  end

  @doc """
  Check if user can view a trip.
  """
  def can_view_trip?(trip, user_id) do
    cond do
      trip.user_id == user_id -> true
      trip.is_public -> true
      Trip.sharing_valid?(trip) -> true
      has_view_permission?(trip.id, user_id) -> true
      true -> false
    end
  end

  # Private helper functions for sharing

  defp get_collaborator_for_user(collaborator_id, user_id) do
    case Repo.get_by(TripCollaborator, id: collaborator_id, user_id: user_id) do
      %TripCollaborator{} = collaborator -> {:ok, collaborator}
      nil -> {:error, :not_found}
    end
  end

  defp update_collaboration_status(collaborator, status) do
    changeset = TripCollaborator.response_changeset(collaborator, status)
    Repo.update(changeset)
  end

  defp has_edit_permission?(trip_id, user_id) do
    from(c in TripCollaborator,
      where: c.trip_id == ^trip_id and c.user_id == ^user_id and 
             c.status == "accepted" and c.permission_level in ["editor", "admin"]
    )
    |> Repo.exists?()
  end

  defp has_view_permission?(trip_id, user_id) do
    from(c in TripCollaborator,
      where: c.trip_id == ^trip_id and c.user_id == ^user_id and c.status == "accepted"
    )
    |> Repo.exists?()
  end
end