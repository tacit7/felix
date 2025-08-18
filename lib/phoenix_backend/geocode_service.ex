defmodule RouteWiseApi.GeocodeService do
  @moduledoc """
  Service for handling all geocoding and location resolution operations.
  
  Provides a clean interface for:
  - Location geocoding with caching
  - Bounds calculation
  - Location fallbacks (Database → LocationIQ → Google)
  - Location data persistence
  """
  
  alias RouteWiseApi.{Places, LocationDisambiguation, Repo}
  alias RouteWiseApi.Places.City
  
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  # Module for geocoding results
  defmodule LocationResult do
    @moduledoc "Structured result for geocoding operations"
    
    defstruct [:coords, :bounds, :bounds_source, :city_name, :display_name, :metadata]
    
    @type t :: %__MODULE__{
      coords: %{lat: float(), lng: float()},
      bounds: %{north: float(), south: float(), east: float(), west: float()} | nil,
      bounds_source: String.t(),
      city_name: String.t(),
      display_name: String.t(),
      metadata: map()
    }
  end
  
  @doc """
  Geocode a location string with bounds calculation and caching.
  
  ## Examples
      iex> GeocodeService.geocode_with_bounds("Austin")
      %LocationResult{coords: %{lat: 30.2672, lng: -97.7431}, ...}
  """
  @spec geocode_with_bounds(String.t()) :: LocationResult.t() | nil
  def geocode_with_bounds(location_name) when is_binary(location_name) do
    pre!(String.length(location_name) > 0, "Location name cannot be empty")
    
    cache_key = "geocode_bounds:#{String.downcase(location_name)}"
    backend = get_cache_backend()
    
    case backend.get(cache_key) do
      {:ok, cached_data} ->
        Logger.debug("📍 Cache hit for geocoding with bounds: #{location_name}")
        struct(LocationResult, cached_data)
        
      :error ->
        Logger.debug("📍 Cache miss for geocoding with bounds: #{location_name}")
        location_result = fetch_location_with_bounds(location_name)
        
        # Cache for 30 days (locations are stable)
        if location_result do
          serializable_result = Map.from_struct(location_result)
          backend.put(cache_key, serializable_result, :timer.hours(24 * 30))
        end
        
        location_result
    end
  end
  
  @doc """
  Simple coordinate geocoding without bounds (legacy compatibility).
  """
  @spec geocode_coordinates(String.t()) :: %{lat: float(), lng: float()} | nil
  def geocode_coordinates(location_name) when is_binary(location_name) do
    pre!(String.length(location_name) > 0, "Location name cannot be empty")
    
    cache_key = "geocode:#{String.downcase(location_name)}"
    backend = get_cache_backend()
    
    case backend.get(cache_key) do
      {:ok, cached_coords} ->
        Logger.debug("📍 Cache hit for geocoding: #{location_name}")
        cached_coords
        
      :error ->
        Logger.debug("📍 Cache miss for geocoding: #{location_name}")
        coords = fetch_location_coordinates(location_name)
        
        # Cache for 30 days
        if coords do
          backend.put(cache_key, coords, :timer.hours(24 * 30))
        end
        
        coords
    end
  end
  
  @doc """
  Resolve location using enhanced search with disambiguation.
  Returns either database results or LocationIQ fallback.
  """
  @spec resolve_location_enhanced(String.t()) :: {:ok, map(), map()} | {:error, String.t()}
  def resolve_location_enhanced(location) when is_binary(location) do
    pre!(String.length(location) > 0, "Location cannot be empty")
    
    case LocationDisambiguation.enhanced_search(location) do
      {:ok, city, disambiguation_meta} ->
        {:ok, city, disambiguation_meta}
        
      {:error, reason} ->
        Logger.warning("⚠️  Enhanced location search failed: #{reason}, trying LocationIQ fallback")
        fallback_to_location_iq(location)
    end
  end
  
  # Private implementation functions
  
  defp fetch_location_with_bounds(location_name) do
    case Places.search_cities(location_name, limit: 1) do
      {:ok, [city | _]} ->
        Logger.debug("🏙️  Database geocoding with bounds: #{location_name} -> #{city.name}")
        
        bounds = calculate_city_bounds(city)
        
        # Determine the actual bounds source based on city data
        actual_bounds_source = determine_bounds_source(city)
        
        %LocationResult{
          coords: %{lat: city.lat, lng: city.lon},
          bounds: bounds,
          bounds_source: actual_bounds_source,
          city_name: city.name,
          display_name: city.display_name,
          metadata: %{
            city_type: city.city_type,
            country: city.country,
            country_code: city.country_code
          }
        }
        
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
  
  defp fetch_location_coordinates(location_name) do
    case Places.search_cities(location_name, limit: 1) do
      {:ok, [city | _]} ->
        Logger.debug("🏙️  Database-only geocoding hit: #{location_name} -> #{city.name}")
        %{lat: city.lat, lng: city.lon}
        
      {:ok, []} ->
        Logger.debug("🔍 No database results for geocoding: #{location_name}")
        nil
        
      {:error, reason} ->
        Logger.warning("Database city search failed for #{location_name}: #{reason}")
        nil
    end
  rescue
    error ->
      Logger.error("Exception geocoding location #{location_name}: #{Exception.message(error)}")
      nil
  end
  
  defp calculate_city_bounds(city) do
    pre!(city != nil, "City cannot be nil for bounds calculation")
    
    base_radius = determine_city_radius(city)
    
    lat = convert_to_float(city.lat)
    lng = convert_to_float(city.lon)
    
    assert!(is_float(lat) and lat >= -90.0 and lat <= 90.0, "Invalid latitude: #{inspect(lat)}")
    assert!(is_float(lng) and lng >= -180.0 and lng <= 180.0, "Invalid longitude: #{inspect(lng)}")
    
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
  
  defp determine_city_radius(city) do
    city_name = String.downcase(city.name || "")
    display_name = String.downcase(city.display_name || "")
    
    cond do
      # Major metropolitan areas
      city_name in ~w(new_york los_angeles chicago houston phoenix philadelphia san_antonio san_diego dallas san_jose) ->
        0.25  # ~27.5 km radius
        
      # Large cities
      city_name in ~w(austin fort_worth charlotte seattle denver boston nashville baltimore portland las_vegas) ->
        0.15  # ~16.7 km radius
        
      # Medium cities by state
      String.contains?(display_name, ["tx", "texas", "ca", "california", "fl", "florida", "ny", "new york"]) ->
        0.10  # ~11.1 km radius
        
      # International major cities
      String.contains?(display_name, ["london", "paris", "tokyo", "madrid", "berlin", "rome"]) ->
        0.20  # ~22.2 km radius
        
      # Default for smaller cities
      true ->
        0.05  # ~5.6 km radius
    end
  end
  
  defp fallback_to_location_iq(location) do
    Logger.info("🌐 Using LocationIQ API fallback for location: #{location}")
    
    case RouteWiseApi.LocationIQ.geocode(location) do
      {:ok, [%{lat: lat, lon: lon} = location_data | _]} ->
        Logger.info("📍 LocationIQ found coordinates: #{lat}, #{lon}")
        
        # Convert and save to database for future use
        save_location_to_database(location, location_data)
        
        # Return in expected format
        city_data = %{
          name: extract_city_name(location_data),
          display_name: location_data["display_name"] || location,
          lat: lat,
          lon: lon,
          country: location_data["country"] || "Unknown",
          country_code: String.downcase(location_data["country_code"] || "us")
        }
        
        disambiguation_meta = %{
          disambiguation: :none,
          alternatives: [],
          source: "location_iq"
        }
        
        {:ok, city_data, disambiguation_meta}
        
      {:error, reason} ->
        Logger.warning("⚠️  LocationIQ geocoding failed: #{reason}")
        {:error, "Could not find location: #{location}"}
    end
  rescue
    error ->
      Logger.error("Exception in LocationIQ fallback: #{Exception.message(error)}")
      {:error, "API fallback failed: #{Exception.message(error)}"}
  end
  
  defp save_location_to_database(location, location_data) do
    try do
      display_name = location_data["display_name"] || location
      lat = convert_to_float(location_data["lat"])
      lng = convert_to_float(location_data["lon"])
      
      assert!(is_float(lat), "Invalid latitude from LocationIQ: #{inspect(location_data["lat"])}")
      assert!(is_float(lng), "Invalid longitude from LocationIQ: #{inspect(location_data["lon"])}")
      
      entity_type = case location_data["type"] do
        "city" -> "city"
        "town" -> "city"
        "state" -> "state"
        "country" -> "country"
        _ -> "city"
      end
      
      city_attrs = %{
        location_iq_place_id: location_data["place_id"] || "locationiq_#{System.unique_integer()}",
        name: extract_city_name(location_data),
        display_name: display_name,
        latitude: Decimal.new(to_string(lat)),
        longitude: Decimal.new(to_string(lng)),
        city_type: entity_type,
        country: location_data["country"] || "Unknown",
        country_code: String.downcase(location_data["country_code"] || "us"),
        entity_type: entity_type,
        normalized_name: Places.normalize_location_input(location),
        search_count: 1,
        last_searched_at: DateTime.utc_now()
      }
      
      case Repo.insert(City.changeset(%City{}, city_attrs)) do
        {:ok, city} ->
          Logger.info("💾 Saved new location to database: #{city.name}")
        {:error, changeset} ->
          Logger.warning("⚠️  Could not save location to database: #{inspect(changeset.errors)}")
      end
    rescue
      error ->
        Logger.error("Exception saving location: #{Exception.message(error)}")
    end
  end
  
  defp extract_city_name(location_data) do
    display_name = location_data["display_name"] || ""
    city_name = String.trim(String.split(display_name, ",") |> List.first() || "Unknown")
    
    pre!(String.length(city_name) > 0, "City name cannot be empty")
    city_name
  end
  
  defp convert_to_float(value) when is_float(value), do: value
  defp convert_to_float(value) when is_binary(value), do: String.to_float(value)
  defp convert_to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp convert_to_float(value) when is_integer(value), do: value * 1.0
  
  defp get_cache_backend do
    try do
      RouteWiseApi.Caching.backend()
    rescue
      _ -> RouteWiseApi.Caching.Backend.Memory
    end
  end
  
  # Clean bounds source determination (matches ExploreResultsController logic)
  defp determine_bounds_source(city) do
    cond do
      # Check if OSM bounds are present and complete
      not is_nil(city.bbox_north) and not is_nil(city.bbox_south) and
      not is_nil(city.bbox_east) and not is_nil(city.bbox_west) -> 
        "osm"
      
      # Check if calculated radius is available
      city.search_radius_meters && city.search_radius_meters > 0 -> 
        "calculated_from_radius"
      
      # Fallback to legacy
      true -> 
        "legacy_calculated"
    end
  end
end