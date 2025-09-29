defmodule RouteWiseApi.BoundsService do
  @moduledoc """
  Service for calculating geographic bounds and search radii for cities and places.
  
  Handles:
  - OSM bounds extraction and validation
  - Radius-based bounds calculation
  - Legacy bounds calculation for fallback
  - Bounds source determination
  """
  
  alias RouteWiseApi.TypeUtils
  
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  @doc """
  Calculate bounds around specific coordinates with a given radius.
  """
  def calculate_coordinate_bounds(lat, lon, radius_meters \\ 5000) do
    pre!(is_float(lat) and lat >= -90.0 and lat <= 90.0, "lat must be valid coordinate")
    pre!(is_float(lon) and lon >= -180.0 and lon <= 180.0, "lon must be valid coordinate")
    pre!(is_integer(radius_meters) and radius_meters > 0, "radius_meters must be positive integer")

    # Convert radius to degrees (approximate)
    # 1 degree of latitude ≈ 111,320 meters
    # 1 degree of longitude varies by latitude, but we'll use a simplified calculation
    lat_offset = radius_meters / 111_320.0
    lon_offset = radius_meters / (111_320.0 * :math.cos(lat * :math.pi() / 180.0))

    bounds = %{
      north: min(lat + lat_offset, 90.0),
      south: max(lat - lat_offset, -90.0),
      east: min(lon + lon_offset, 180.0),
      west: max(lon - lon_offset, -180.0)
    }

    post!(bounds.north > bounds.south, "Calculated bounds invalid: north <= south")
    post!(TypeUtils.valid_coordinate?(bounds.north, :lat), "Calculated invalid north coordinate")
    post!(TypeUtils.valid_coordinate?(bounds.south, :lat), "Calculated invalid south coordinate")
    post!(TypeUtils.valid_coordinate?(bounds.east, :lng), "Calculated invalid east coordinate")
    post!(TypeUtils.valid_coordinate?(bounds.west, :lng), "Calculated invalid west coordinate")

    bounds
  end

  @doc """
  Calculate appropriate bounds for a city using Geographic Bounds System.
  """
  def calculate_city_bounds(city) do
    # Input contract assertion (our code should never pass nil)
    pre!(not is_nil(city), "calculate_city_bounds/1 requires non-nil city")
    pre!(is_binary(city.name), "calculate_city_bounds/1 requires city with name")
    
    case do_calculate_bounds(city) do
      {:ok, bounds} ->
        # Output contract assertion (our algorithm should produce valid bounds)
        post!(bounds.north > bounds.south, "Algorithm produced invalid bounds: north <= south")
        post!(TypeUtils.valid_coordinate?(bounds.north, :lat), "Algorithm produced invalid north coordinate")
        post!(TypeUtils.valid_coordinate?(bounds.south, :lat), "Algorithm produced invalid south coordinate")
        post!(TypeUtils.valid_coordinate?(bounds.east, :lng), "Algorithm produced invalid east coordinate")
        post!(TypeUtils.valid_coordinate?(bounds.west, :lng), "Algorithm produced invalid west coordinate")
        
        bounds
      
      {:error, reason} ->
        Logger.error("Failed to calculate bounds for #{city.name}: #{reason}")
        # Return fallback bounds rather than crash
        get_fallback_bounds()
    end
  end

  @doc """
  Determine the source of bounds data for a city.
  """
  def determine_bounds_source(city) do
    bounds_source = cond do
      all_osm_bounds_present?(city) -> "osm"
      city.search_radius_meters && city.search_radius_meters > 0 -> "calculated_from_radius"
      true -> "legacy_calculated"
    end
    
    Logger.debug("📊 Bounds source for #{city.name}: #{bounds_source}")
    bounds_source
  end

  @doc """
  Calculate bounds for a cached place based on place type.
  """
  def calculate_cached_place_bounds(cached_place) do
    # Calculate bounds based on place type
    base_radius = case cached_place.place_type do
      1 -> 2.0   # Country - large bounds (200km)
      3 -> 0.15  # City - medium bounds (16km)  
      5 -> 0.05  # POI - small bounds (5km)
      _ -> 0.10  # Default
    end
    
    lat = cached_place.lat
    lng = cached_place.lon
    
    # Account for latitude distortion
    lat_factor = :math.cos(lat * :math.pi() / 180)
    lng_radius = base_radius / lat_factor
    
    %{
      north: lat + base_radius,
      south: lat - base_radius,
      east: lng + lng_radius,
      west: lng - lng_radius
    }
  end

  # Private implementation functions

  defp do_calculate_bounds(city) do
    cond do
      all_osm_bounds_present?(city) ->
        extract_osm_bounds(city)
        
      city.search_radius_meters && city.search_radius_meters > 0 ->
        calculate_bounds_from_radius_meters(city)
        
      true ->
        calculate_legacy_bounds(city)
    end
  end

  # OSM bounds extraction with validation
  defp extract_osm_bounds(city) do
    Logger.debug("🗺️ Using OSM bounds for #{city.name}: #{city.search_radius_meters}m radius")
    
    with {:ok, north} <- TypeUtils.parse_coordinate(city.bbox_north, :lat),
         {:ok, south} <- TypeUtils.parse_coordinate(city.bbox_south, :lat),
         {:ok, east} <- TypeUtils.parse_coordinate(city.bbox_east, :lng),
         {:ok, west} <- TypeUtils.parse_coordinate(city.bbox_west, :lng) do
      
      bounds = %{north: north, south: south, east: east, west: west}
      
      # Business rule validation (not assertion - this is external data)
      cond do
        north <= south -> {:error, "OSM bounds invalid: north <= south"}
        east == west -> {:error, "OSM bounds invalid: east == west"} 
        abs(north - south) < 0.001 -> {:error, "OSM bounds too small"}
        true -> {:ok, bounds}
      end
    else
      {:error, reason} -> {:error, "OSM bounds parsing failed: #{reason}"}
    end
  end

  # Calculate bounds from radius in meters with validation
  defp calculate_bounds_from_radius_meters(city) do
    Logger.debug("📏 Using calculated bounds for #{city.name}: #{city.search_radius_meters}m radius")
    
    case TypeUtils.extract_coordinates(city) do
      {:ok, {lat, lng}} ->
        radius_meters = city.search_radius_meters
        
        # Convert meters to degrees (approximately)
        # 1 degree latitude ≈ 111,000 meters
        lat_radius = radius_meters / 111_000
        
        # Account for latitude distortion (longitude degrees get smaller near poles)
        lat_factor = :math.cos(lat * :math.pi() / 180)
        lng_radius = lat_radius / lat_factor
        
        bounds = %{
          north: lat + lat_radius,
          south: lat - lat_radius,
          east: lng + lng_radius,
          west: lng - lng_radius
        }
        
        {:ok, bounds}
      
      {:error, reason} ->
        {:error, "Radius bounds calculation failed: #{reason}"}
    end
  end

  # Calculate legacy bounds with validation
  defp calculate_legacy_bounds(city) do
    Logger.debug("⚠️ Using legacy bounds calculation for #{city.name}")
    
    case TypeUtils.extract_coordinates(city) do
      {:ok, {lat, lng}} ->
        base_radius = determine_city_radius_legacy(city)
        assert!(base_radius > 0, "Legacy radius calculation returned invalid radius: #{base_radius}")
        
        # Account for latitude distortion (longitude degrees get smaller near poles)
        lat_factor = :math.cos(lat * :math.pi() / 180)
        lng_radius = base_radius / lat_factor
        
        bounds = %{
          north: lat + base_radius,
          south: lat - base_radius,
          east: lng + lng_radius,
          west: lng - lng_radius
        }
        
        {:ok, bounds}
      
      {:error, reason} ->
        {:error, "Legacy bounds calculation failed: #{reason}"}
    end
  end

  # Check if all OSM bounds are present
  defp all_osm_bounds_present?(city) do
    not is_nil(city.bbox_north) and not is_nil(city.bbox_south) and
    not is_nil(city.bbox_east) and not is_nil(city.bbox_west)
  end

  # Fallback bounds when all else fails
  defp get_fallback_bounds do
    Logger.warning("⚠️ Using fallback bounds - this indicates a data quality issue")
    %{
      north: 1.0,
      south: -1.0,
      east: 1.0,
      west: -1.0
    }
  end

  # Legacy hardcoded radius determination (kept as fallback)
  defp determine_city_radius_legacy(city) do
    city_name = String.downcase(city.name || "")
    display_name = String.downcase(city.display_name || "")
    
    cond do
      # Major metropolitan areas - larger bounds
      city_name in ["new york", "los angeles", "chicago", "houston", "phoenix", "philadelphia", "san antonio", "san diego", "dallas", "san jose"] ->
        0.25  # ~27.5 km radius
        
      # Large cities - medium bounds  
      city_name in ["austin", "fort worth", "charlotte", "seattle", "denver", "boston", "nashville", "baltimore", "portland", "las vegas"] ->
        0.15  # ~16.7 km radius
        
      # Medium cities - smaller bounds
      String.contains?(display_name, ["tx", "texas", "ca", "california", "fl", "florida", "ny", "new york"]) ->
        0.10  # ~11.1 km radius
        
      # International cities - vary by importance
      String.contains?(display_name, ["london", "paris", "tokyo", "madrid", "berlin", "rome"]) ->
        0.20  # ~22.2 km radius
        
      # Default for smaller cities/towns
      true ->
        0.05  # ~5.6 km radius
    end
  end
end