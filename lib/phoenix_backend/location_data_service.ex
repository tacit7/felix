defmodule RouteWiseApi.LocationDataService do
  @moduledoc """
  Service for building location data structures with coordinates, bounds, and metadata.
  
  Handles:
  - Location data building from cached places
  - Location data building from city database records
  - Geocoding integration with bounds calculation
  - Location data caching and retrieval
  """
  
  alias RouteWiseApi.{Places, BoundsService, CacheService}
  
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  @doc """
  Build location data from direct coordinates.
  """
  def build_coordinate_location_data(lat, lon, location_name) do
    pre!(is_float(lat) and lat >= -90.0 and lat <= 90.0, "lat must be valid coordinate")
    pre!(is_float(lon) and lon >= -180.0 and lon <= 180.0, "lon must be valid coordinate")
    pre!(is_binary(location_name) and byte_size(location_name) > 0, "location_name must be non-empty string")

    Logger.debug("📍 Using direct coordinates: #{location_name} -> (#{lat}, #{lon})")

    # Build simple bounds around the coordinates (default 5km radius)
    bounds = BoundsService.calculate_coordinate_bounds(lat, lon, 5000)

    location_data = %{
      coords: %{lat: lat, lng: lon},
      bounds: bounds,
      bounds_source: "coordinates",
      city_name: location_name,
      display_name: location_name,
      # Geographic context not available for raw coordinates
      state: nil,
      country: nil,
      country_code: nil,
      formatted_address: "#{lat}, #{lon}",
      metadata: %{
        source: "coordinates"
      }
    }

    post!(is_map(location_data.coords), "location_data.coords must be a map")
    post!(is_map(location_data.bounds), "location_data.bounds must be a map")

    location_data
  end

  @doc """
  Build location data from a cached place.
  """
  def build_cached_place_location_data(cached_place) do
    pre!(not is_nil(cached_place), "cached_place cannot be nil")
    pre!(is_float(cached_place.lat) and is_float(cached_place.lon), "cached place must have valid coordinates")
    pre!(is_binary(cached_place.name) and byte_size(cached_place.name) > 0, "cached place must have valid name")

    location_data = %{
      coords: %{lat: cached_place.lat, lng: cached_place.lon},
      bounds: BoundsService.calculate_cached_place_bounds(cached_place),
      bounds_source: "cached_place",
      city_name: cached_place.name,
      display_name: cached_place.name,
      # Include geographic context if available in cached place
      state: Map.get(cached_place, :state),
      country: Map.get(cached_place, :country),
      country_code: Map.get(cached_place, :country_code),
      formatted_address: cached_place.name,
      metadata: %{
        place_type: Map.get(cached_place, :place_type, "cached"),
        place_id: cached_place.id
      }
    }

    post!(is_map(location_data.coords), "location_data.coords must be a map")
    post!(is_map(location_data.bounds), "location_data.bounds must be a map")

    location_data
  end

  @doc """
  Build location data from a city database record.
  """
  def build_city_location_data(city, location_name) do
    pre!(not is_nil(city), "city cannot be nil")
    pre!(is_binary(city.name) and byte_size(city.name) > 0, "city must have valid name")

    Logger.debug("🏙️  Database geocoding with bounds: #{location_name} -> #{city.name}")

    # Calculate bounds based on city size and importance
    bounds = BoundsService.calculate_city_bounds(city)

    # Determine the actual bounds source
    bounds_source = BoundsService.determine_bounds_source(city)

    %{
      coords: %{lat: city.lat, lng: city.lon},
      bounds: bounds,
      bounds_source: bounds_source,
      city_name: city.name,
      display_name: city.display_name,
      # Include rich geographic context
      state: city.state,
      country: city.country,
      country_code: city.country_code,
      formatted_address: city.display_name,
      metadata: %{
        city_type: city.city_type,
        entity_type: Map.get(city, :entity_type)
      }
    }
  end

  @doc """
  Fetch location with bounds using database geocoding and caching.
  """
  def fetch_location_with_bounds_cached(location_name) do
    CacheService.geocode_city_with_bounds_cache(location_name, fn ->
      fetch_location_with_bounds(location_name)
    end)
  end

  # Private implementation functions

  defp fetch_location_with_bounds(location_name) do
    # First try database-only geocoding  
    case Places.search_cities(location_name, limit: 1) do
      {:ok, [city | _]} ->
        build_city_location_data(city, location_name)
        
      {:ok, []} ->
        Logger.debug("🔍 No database results for bounds calculation: #{location_name}")
        nil
        
      {:error, reason} ->
        Logger.warning("Database city search failed for #{location_name}: #{reason}")
        nil
    end
  rescue
    error ->
      Logger.error("Exception calculating bounds for #{location_name}: #{Exception.message(error)}")
      nil
  end
end