defmodule RouteWiseApi.CachedPlacesService do
  @moduledoc """
  Service for managing cached places operations.
  
  Handles:
  - Cached place lookups and validation
  - Search count incrementation
  - Bounds calculation for cached places
  - POI fetching for cached place coordinates
  """
  
  alias RouteWiseApi.{Repo, POIFetchingService, TypeUtils}
  alias RouteWiseApi.Places.CachedPlace
  
  import Ecto.Query
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  @doc """
  Get a cached place by ID with validation.
  
  ## Examples
      iex> CachedPlacesService.get_cached_place("uuid-here")
      {:ok, %CachedPlace{name: "Austin", lat: 30.2672, ...}}
      
      iex> CachedPlacesService.get_cached_place("invalid-id")
      {:error, :not_found}
  """
  @spec get_cached_place(String.t()) :: {:ok, CachedPlace.t()} | {:error, :not_found}
  def get_cached_place(place_id) when is_binary(place_id) do
    pre!(String.length(place_id) > 0, "Place ID cannot be empty")
    
    case Repo.get(CachedPlace, place_id) do
      nil -> 
        Logger.warning("Cached place not found: #{place_id}")
        {:error, :not_found}
      cached_place -> 
        Logger.info("🎯 Found cached place: #{cached_place.name} (#{cached_place.lat}, #{cached_place.lon})")
        {:ok, cached_place}
    end
  rescue
    error ->
      Logger.error("Exception getting cached place #{place_id}: #{Exception.message(error)}")
      {:error, :not_found}
  end
  
  @doc """
  Increment search count for a cached place.
  This tracks usage analytics but doesn't fail the request if it can't update.
  """
  @spec increment_search_count(CachedPlace.t()) :: :ok | :error
  def increment_search_count(%CachedPlace{} = cached_place) do
    try do
      cached_place
      |> CachedPlace.increment_search_changeset()
      |> Repo.update()
      
      Logger.debug("📊 Incremented search count for #{cached_place.name}")
      :ok
    rescue
      error ->
        Logger.warning("Failed to increment search count for #{cached_place.name}: #{Exception.message(error)}")
        :error
    end
  end
  
  @doc """
  Calculate appropriate bounds for a cached place based on its type.
  
  ## Place Types
  - 1: Country - large bounds (200km)
  - 3: City - medium bounds (16km) 
  - 5: POI - small bounds (5km)
  """
  @spec calculate_bounds(CachedPlace.t()) :: %{north: float(), south: float(), east: float(), west: float()}
  def calculate_bounds(%CachedPlace{} = cached_place) do
    pre!(is_float(cached_place.lat) or is_number(cached_place.lat), "Invalid latitude in cached place")
    pre!(is_float(cached_place.lon) or is_number(cached_place.lon), "Invalid longitude in cached place")
    
    base_radius = determine_place_radius(cached_place.place_type)
    
    lat = TypeUtils.ensure_float_or_zero(cached_place.lat)
    lng = TypeUtils.ensure_float_or_zero(cached_place.lon)
    
    assert!(lat >= -90.0 and lat <= 90.0, "Latitude out of valid range: #{lat}")
    assert!(lng >= -180.0 and lng <= 180.0, "Longitude out of valid range: #{lng}")
    
    # Account for latitude distortion (longitude degrees get smaller near poles)
    lat_factor = :math.cos(lat * :math.pi() / 180)
    lng_radius = base_radius / lat_factor
    
    %{
      north: lat + base_radius,
      south: lat - base_radius,
      east: lng + lng_radius,
      west: lng - lng_radius
    }
  end
  
  @doc """
  Fetch POIs for a cached place using its coordinates and type-appropriate radius.
  """
  @spec fetch_pois_for_cached_place(CachedPlace.t(), map()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch_pois_for_cached_place(%CachedPlace{} = cached_place, params \\ %{}) do
    # Determine search radius based on place type
    search_radius = determine_search_radius(cached_place, params)
    
    Logger.info("🎯 Searching POIs around #{cached_place.name} with #{search_radius}m radius")
    
    # Use POI fetching service with cached place coordinates
    POIFetchingService.fetch_pois_for_cached_place(cached_place, params)
  end
  
  @doc """
  Create location data structure from cached place for API responses.
  """
  @spec build_location_data(CachedPlace.t()) :: map()
  def build_location_data(%CachedPlace{} = cached_place) do
    %{
      coords: %{lat: cached_place.lat, lng: cached_place.lon},
      bounds: calculate_bounds(cached_place),
      bounds_source: "cached_place",
      city_name: cached_place.name,
      display_name: cached_place.name,
      metadata: %{
        place_id: cached_place.id,
        place_type: cached_place.place_type,
        search_count: cached_place.search_count || 0,
        last_searched_at: cached_place.last_searched_at
      }
    }
  end
  
  @doc """
  Get all cached places, optionally filtered by type.
  """
  @spec list_cached_places(integer() | nil) :: [CachedPlace.t()]
  def list_cached_places(place_type \\ nil) do
    query = if place_type do
      from(cp in CachedPlace, where: cp.place_type == ^place_type)
    else
      CachedPlace
    end
    
    Repo.all(query)
  rescue
    error ->
      Logger.error("Exception listing cached places: #{Exception.message(error)}")
      []
  end
  
  @doc """
  Search cached places by name.
  """
  @spec search_cached_places(String.t(), integer()) :: [CachedPlace.t()]
  def search_cached_places(query, limit \\ 10) when is_binary(query) do
    pre!(String.length(query) > 0, "Search query cannot be empty")
    pre!(limit > 0 and limit <= 100, "Limit must be between 1 and 100")
    
    search_term = "%#{String.downcase(query)}%"
    
    from(cp in CachedPlace,
      where: ilike(cp.name, ^search_term) or ilike(cp.display_name, ^search_term),
      order_by: [desc: cp.search_count, asc: cp.name],
      limit: ^limit
    )
    |> Repo.all()
  rescue
    error ->
      Logger.error("Exception searching cached places: #{Exception.message(error)}")
      []
  end
  
  # Private implementation functions
  
  defp determine_place_radius(place_type) do
    case place_type do
      1 -> 2.0   # Country - large bounds (~200km)
      3 -> 0.15  # City - medium bounds (~16km)
      5 -> 0.05  # POI - small bounds (~5km)
      _ -> 0.10  # Default - medium bounds (~10km)
    end
  end
  
  defp determine_search_radius(%CachedPlace{} = cached_place, params) do
    # Base radius by place type
    base_radius = case cached_place.place_type do
      1 -> 100_000  # Country - 100km radius
      3 -> 20_000   # City - 20km radius
      5 -> 10_000   # POI - 10km radius
      _ -> 15_000   # Default - 15km radius
    end
    
    # Allow override from params
    case Map.get(params, "radius") do
      nil -> base_radius
      radius_str when is_binary(radius_str) ->
        case Integer.parse(radius_str) do
          {radius_int, ""} when radius_int > 0 and radius_int <= 100_000 -> radius_int
          _ -> base_radius
        end
      radius_int when is_integer(radius_int) and radius_int > 0 and radius_int <= 100_000 -> 
        radius_int
      _ -> base_radius
    end
  end
  
end