defmodule RouteWiseApi.POIFetchingService do
  @moduledoc """
  Service for fetching POIs from multiple sources with intelligent fallback.
  
  Supports:
  - Database-first POI fetching
  - Google Places API with caching
  - OpenStreetMap integration
  - Smart source selection and fallback
  """
  
  alias RouteWiseApi.{PlacesService, GooglePlaces, OSMPlaces, Places, Caching}
  alias RouteWiseApi.GeocodeService
  alias RouteWiseApi.TypeUtils
  
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  @type poi_source :: :auto | :database | :google | :osm
  @type coordinates :: %{lat: float(), lng: float()}
  @type fetch_options :: %{
    source: poi_source(),
    radius: integer(),
    categories: [String.t()],
    limit: integer()
  }
  
  @default_options %{
    source: :auto,
    radius: 5_000,
    categories: [],
    limit: 50
  }
  
  @doc """
  Fetch POIs for a location using intelligent source selection.
  
  ## Examples
      iex> POIFetchingService.fetch_pois_for_location("Austin", %{source: :auto})
      {:ok, [%{name: "Restaurant", lat: 30.2672, ...}, ...]}
  """
  @spec fetch_pois_for_location(String.t(), map()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch_pois_for_location(location, params \\ %{}) when is_binary(location) do
    pre!(String.length(location) > 0, "Location cannot be empty")
    
    options = parse_options(params)
    
    case options.source do
      :google ->
        fetch_google_pois_for_location(location, options)
      :osm ->
        fetch_osm_pois_for_location(location, options)
      :database ->
        fetch_database_pois_for_location(location, options)
      :auto ->
        fetch_pois_with_smart_fallback(location, options)
    end
  rescue
    error ->
      Logger.error("Exception in fetch_pois_for_location: #{Exception.message(error)}")
      {:error, "Failed to fetch POIs: #{Exception.message(error)}"}
  end
  
  @doc """
  Fetch POIs for cached place using coordinates.
  """
  @spec fetch_pois_for_cached_place(map(), map()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch_pois_for_cached_place(cached_place, params \\ %{}) do
    pre!(Map.has_key?(cached_place, :lat), "Cached place must have latitude")
    pre!(Map.has_key?(cached_place, :lng) or Map.has_key?(cached_place, :lon), "Cached place must have longitude")
    
    options = parse_options(params)
    
    # Calculate radius based on place type
    radius = determine_cached_place_radius(cached_place, options.radius)
    final_options = %{options | radius: radius}
    
    coordinates = %{
      lat: cached_place.lat,
      lng: cached_place.lng || cached_place.lon
    }
    
    case final_options.source do
      :osm ->
        fetch_osm_pois_by_coordinates(coordinates, final_options)
      :database ->
        fetch_database_pois_by_coordinates(coordinates, final_options)
      :auto ->
        fetch_pois_by_coordinates_with_fallback(coordinates, final_options)
      _ ->
        fetch_pois_by_coordinates_with_fallback(coordinates, final_options)
    end
  end
  
  @doc """
  Fetch Google Places POIs with aggressive caching.
  """
  @spec fetch_google_places_cached(String.t(), float(), float(), map()) :: [map()]
  def fetch_google_places_cached(location, lat, lng, options \\ %{}) do
    assert!(is_float(lat) and lat >= -90.0 and lat <= 90.0, "Invalid latitude: #{lat}")
    assert!(is_float(lng) and lng >= -180.0 and lng <= 180.0, "Invalid longitude: #{lng}")
    
    parsed_options = parse_options(options)
    
    # Create cache key for 6-month caching
    cache_key = "google_places:#{location}:#{lat}:#{lng}:#{parsed_options.radius}"
    cache_ttl_seconds = 6 * 30 * 24 * 60 * 60  # 6 months
    
    case Caching.get(cache_key) do
      {:ok, cached_pois} ->
        Logger.info("🎯 Google Places cache HIT for #{location} (#{length(cached_pois)} POIs)")
        cached_pois
        
      :error ->
        Logger.info("🔍 Google Places cache MISS - fetching from API for #{location}")
        
        case fetch_google_places_api(lat, lng, parsed_options.radius) do
          {:ok, google_pois} when length(google_pois) > 0 ->
            # Store permanently in database and cache
            stored_pois = store_google_places_in_database(google_pois, location)
            Caching.put(cache_key, stored_pois, ttl: cache_ttl_seconds)
            
            Logger.info("✅ Stored #{length(stored_pois)} Google Places POIs")
            stored_pois
            
          {:ok, []} ->
            Logger.warning("⚠️ Google Places returned no results for #{location}")
            []
            
          {:error, reason} ->
            Logger.error("❌ Google Places API error: #{inspect(reason)}")
            []
        end
    end
  rescue
    error ->
      Logger.error("Exception in fetch_google_places_cached: #{Exception.message(error)}")
      []
  end
  
  # Private implementation functions
  
  defp fetch_pois_with_smart_fallback(location, options) do
    Logger.info("🔄 Smart fallback strategy for #{location}")
    
    # Try database first
    case fetch_database_pois_for_location(location, options) do
      {:ok, database_pois} when length(database_pois) >= 15 ->
        Logger.info("🎯 Using #{length(database_pois)} database POIs (excellent coverage)")
        {:ok, database_pois}
        
      {:ok, database_pois} ->
        Logger.info("📍 Database has #{length(database_pois)} POIs, fetching Google Places for coverage")
        
        case fetch_google_pois_for_location(location, options) do
          {:ok, google_pois} when length(google_pois) > 0 ->
            combined_pois = RouteWiseApi.POIDeduplicationService.combine_and_deduplicate(database_pois, google_pois)
            Logger.info("✅ Combined: #{length(combined_pois)} POIs (database + Google)")
            {:ok, combined_pois}
            
          _ ->
            Logger.info("⚠️ Google Places failed, falling back to OSM")
            case fetch_osm_pois_for_location(location, options) do
              {:ok, osm_pois} ->
                combined_pois = RouteWiseApi.POIDeduplicationService.combine_and_deduplicate(database_pois, osm_pois)
                Logger.info("✅ Combined: #{length(combined_pois)} POIs (database + OSM)")
                {:ok, combined_pois}
              error -> error
            end
        end
        
      error -> error
    end
  end
  
  defp fetch_database_pois_for_location(location, options) do
    case GeocodeService.resolve_location_enhanced(location) do
      {:ok, city, _disambiguation_meta} ->
        coordinates = %{
          lat: Map.get(city, :lat) || Map.get(city, :latitude),
          lng: Map.get(city, :lon) || Map.get(city, :longitude)
        }
        
        # Calculate radius from bounds if available, otherwise use default
        bounds_radius = calculate_radius_from_city_bounds(city)
        final_radius = bounds_radius || options.radius
        
        Logger.info("🎯 Using radius for #{city.name}: #{final_radius}m (bounds-aware: #{not is_nil(bounds_radius)})")
        
        final_options = %{options | radius: final_radius}
        fetch_database_pois_by_coordinates(coordinates, final_options)
        
      {:error, reason} ->
        Logger.warning("Failed to resolve location for database POI search: #{reason}")
        {:error, reason}
    end
  end
  
  defp fetch_database_pois_by_coordinates(coordinates, options) do
    case PlacesService.search_places("", coordinates, radius: options.radius) do
      {:ok, pois} ->
        Logger.info("🎯 PlacesService returned #{length(pois)} POIs (database-first)")
        {:ok, pois}
        
      {:error, reason} ->
        Logger.warning("⚠️  PlacesService failed: #{reason}, using fallback")
        fallback_pois = Places.search_places_near(coordinates, nil, options.radius)
        {:ok, fallback_pois}
    end
  rescue
    error ->
      Logger.error("Exception in fetch_database_pois_by_coordinates: #{Exception.message(error)}")
      {:error, "Database POI fetch failed: #{Exception.message(error)}"}
  end
  
  defp fetch_google_pois_for_location(location, options) do
    Logger.info("🏢 Fetching Google Places for #{location}")
    
    case GeocodeService.resolve_location_enhanced(location) do
      {:ok, city, _disambiguation_meta} ->
        lat = Map.get(city, :lat) || Map.get(city, :latitude)
        lng = Map.get(city, :lng) || Map.get(city, :lng) || Map.get(city, :longitude)
        
        if lat && lng do
          google_pois = fetch_google_places_cached(location, lat, lng, options)
          {:ok, google_pois}
        else
          Logger.error("❌ No coordinates found for location: #{location}")
          {:error, "No coordinates available"}
        end
        
      {:error, reason} ->
        Logger.error("❌ Failed to geocode location for Google Places: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp fetch_osm_pois_for_location(location, options) do
    case GeocodeService.resolve_location_enhanced(location) do
      {:ok, city, _disambiguation_meta} ->
        coordinates = %{
          lat: Map.get(city, :lat) || Map.get(city, :latitude),
          lng: Map.get(city, :lon) || Map.get(city, :longitude)
        }
        
        fetch_osm_pois_by_coordinates(coordinates, options)
        
      {:error, reason} ->
        Logger.error("❌ Failed to geocode location for OSM search: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp fetch_osm_pois_by_coordinates(coordinates, options) do
    Logger.info("🗺️  Using OSM search at (#{coordinates.lat}, #{coordinates.lng})")
    
    case OSMPlaces.search_nearby(coordinates.lat, coordinates.lng, options.radius, options.categories, options.limit) do
      {:ok, osm_places} ->
        Logger.info("✅ OSM search success: #{length(osm_places)} places found")
        {:ok, osm_places}
        
      {:error, reason} ->
        Logger.error("❌ OSM search failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Exception in fetch_osm_pois_by_coordinates: #{Exception.message(error)}")
      {:error, "OSM POI fetch failed: #{Exception.message(error)}"}
  end
  
  defp fetch_pois_by_coordinates_with_fallback(coordinates, options) do
    # Try database first, then OSM as fallback
    case fetch_database_pois_by_coordinates(coordinates, options) do
      {:ok, database_pois} ->
        case fetch_osm_pois_by_coordinates(coordinates, options) do
          {:ok, osm_pois} ->
            combined_pois = RouteWiseApi.POIDeduplicationService.combine_and_deduplicate(database_pois, osm_pois)
            {:ok, combined_pois}
          _ ->
            {:ok, database_pois}
        end
      error -> error
    end
  end
  
  defp fetch_google_places_api(lat, lng, radius) do
    pre!(is_float(lat) and lat >= -90.0 and lat <= 90.0, "Invalid latitude for Google Places API: #{lat}")
    pre!(is_float(lng) and lng >= -180.0 and lng <= 180.0, "Invalid longitude for Google Places API: #{lng}")
    pre!(is_integer(radius) and radius >= 100 and radius <= 50_000, "Invalid radius for Google Places API: #{radius} (must be 100-50000)")
    
    location = %{lat: lat, lng: lng}
    opts = [radius: radius]
    
    case GooglePlaces.nearby_search(location, opts) do
      {:ok, %{"results" => results, "status" => "OK"}} ->
        assert!(is_list(results), "Google Places API results must be a list")
        assert!(Enum.all?(results, &is_map/1), "All Google Places results must be maps")
        Logger.info("🏢 Google Places nearby search: #{length(results)} results")
        {:ok, results}
        
      {:ok, %{"results" => results, "status" => "ZERO_RESULTS"}} ->
        assert!(is_list(results), "Google Places API zero results must still return a list")
        Logger.info("🏢 Google Places API: zero results")
        {:ok, results}
        
      {:ok, %{"status" => status}} ->
        assert!(is_binary(status), "Google Places API status must be a string")
        Logger.error("❌ Google Places API error status: #{status}")
        {:error, {:api_error, status}}
        
      {:error, reason} ->
        Logger.error("❌ Google Places API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Exception in fetch_google_places_api: #{Exception.message(error)}")
      {:error, {:exception, error}}
  end
  
  @doc """
  Store Google Places POIs in the database with deduplication handling.
  """
  def store_google_places_in_database(google_places, location) do
    Logger.info("💾 Storing #{length(google_places)} Google Places in database for #{location}")
    
    google_places
    |> Enum.map(&RouteWiseApi.POIFormatterService.convert_google_to_poi_format/1)
    |> Enum.reduce([], fn poi, acc ->
      try do
        place_attrs = convert_poi_to_database_attrs(poi)
        
        case Places.create_place(place_attrs) do
          {:ok, _place} ->
            Logger.debug("✅ Stored: #{Map.get(poi, :name, "Unnamed")}")
            [poi | acc]
            
          {:error, %Ecto.Changeset{errors: errors}} ->
            if Keyword.has_key?(errors, :google_place_id) do
              Logger.debug("⚠️ Skipped duplicate: #{Map.get(poi, :name, "Unnamed")}")
            else
              Logger.warning("❌ Failed to store #{Map.get(poi, :name, "Unnamed")}: #{inspect(errors)}")
            end
            [poi | acc]
            
          {:error, reason} ->
            Logger.warning("❌ Failed to store #{Map.get(poi, :name, "Unnamed")}: #{inspect(reason)}")
            [poi | acc]
        end
      rescue
        error ->
          Logger.error("🚨 Exception storing #{Map.get(poi, :name, "Unnamed")}: #{Exception.message(error)}")
          [poi | acc]
      end
    end)
    |> Enum.reverse()
  end
  
  defp convert_poi_to_database_attrs(poi) do
    %{
      google_place_id: Map.get(poi, :google_place_id),
      name: Map.get(poi, :name),
      formatted_address: Map.get(poi, :address),
      latitude: TypeUtils.ensure_decimal(Map.get(poi, :lat)),
      longitude: TypeUtils.ensure_decimal(Map.get(poi, :lng)),
      place_types: Map.get(poi, :place_types, []),
      rating: TypeUtils.ensure_decimal(Map.get(poi, :rating)),
      price_level: Map.get(poi, :price_level),
      phone_number: Map.get(poi, :phone),
      website: Map.get(poi, :website),
      opening_hours: Map.get(poi, :opening_hours),
      photos: Map.get(poi, :photos, []),
      reviews_count: Map.get(poi, :reviews_count, 0),
      google_data: Map.get(poi, :google_data, %{}),
      cached_at: DateTime.utc_now(),
      curated: false
    }
  end
  
  
  defp determine_cached_place_radius(cached_place, default_radius) do
    case Map.get(cached_place, :place_type) do
      1 -> 100_000  # Country - 100km radius
      3 -> 20_000   # City - 20km radius  
      5 -> 10_000   # POI - 10km radius
      _ -> default_radius
    end
  end
  
  defp parse_options(params) do
    %{
      source: parse_source(Map.get(params, "source", "auto")),
      radius: parse_radius(Map.get(params, "radius"), @default_options.radius),
      categories: parse_categories(Map.get(params, "categories"), @default_options.categories),
      limit: parse_limit(Map.get(params, "limit"), @default_options.limit)
    }
  end
  
  defp parse_source("google"), do: :google
  defp parse_source("osm"), do: :osm
  defp parse_source("database"), do: :database
  defp parse_source("auto"), do: :auto
  defp parse_source(_), do: :auto
  
  defp parse_radius(nil, default), do: default
  defp parse_radius(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, ""} when int_val >= 100 and int_val <= 50_000 -> int_val
      _ -> default
    end
  end
  defp parse_radius(value, _default) when is_integer(value) and value >= 100 and value <= 50_000, do: value
  defp parse_radius(_, default), do: default
  
  defp parse_categories(nil, default), do: default
  defp parse_categories(value, default) when is_binary(value) do
    categories = value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&valid_category?/1)
    
    case categories do
      [] -> default
      cats -> cats
    end
  end
  defp parse_categories(_, default), do: default
  
  defp parse_limit(nil, default), do: default
  defp parse_limit(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, ""} when int_val > 0 and int_val <= 100 -> int_val
      _ -> default
    end
  end
  defp parse_limit(value, _default) when is_integer(value) and value > 0 and value <= 100, do: value
  defp parse_limit(_, default), do: default
  
  defp valid_category?(category) do
    category in ["restaurant", "accommodation", "attraction", "shopping", "service", "all"]
  end

  @doc """
  Calculate search radius from city bounds when available.
  
  Returns radius in meters for territory/region-appropriate POI coverage.
  Uses OSM bounds or calculated radius data to determine appropriate search area.
  
  ## Examples
      iex> calculate_radius_from_city_bounds(%{search_radius_meters: 158215})
      158215
      
      iex> calculate_radius_from_city_bounds(%{bbox_north: 18.67, bbox_south: 17.73})
      ~104000  # ~104km calculated from bounds span
  """
  @spec calculate_radius_from_city_bounds(map()) :: integer() | nil
  defp calculate_radius_from_city_bounds(city) do
    cond do
      # Use precomputed search radius (preferred - based on actual geographic analysis)
      city.search_radius_meters && city.search_radius_meters > 0 ->
        # Clamp to reasonable POI search limits
        min(city.search_radius_meters, 200_000)  # Max 200km
        
      # Calculate from OSM bounding box
      has_complete_bbox?(city) ->
        calculate_radius_from_bbox(city)
        
      # No bounds data available
      true ->
        nil
    end
  end

  defp has_complete_bbox?(city) do
    not is_nil(city.bbox_north) and not is_nil(city.bbox_south) and
    not is_nil(city.bbox_east) and not is_nil(city.bbox_west)
  end

  defp calculate_radius_from_bbox(city) do
    try do
      # Convert to floats for calculation
      north = TypeUtils.ensure_float(city.bbox_north)
      south = TypeUtils.ensure_float(city.bbox_south)
      east = TypeUtils.ensure_float(city.bbox_east)
      west = TypeUtils.ensure_float(city.bbox_west)
      
      # Calculate spans in degrees
      lat_span = north - south
      lng_span = east - west
      
      # Convert to approximate meters (1 degree lat ≈ 111km)
      lat_meters = lat_span * 111_000
      
      # Account for longitude distortion at this latitude
      center_lat = (north + south) / 2
      lat_factor = :math.cos(center_lat * :math.pi() / 180)
      lng_meters = lng_span * 111_000 * lat_factor
      
      # Use the larger dimension for radius (covers the full area)
      max_span_meters = max(lat_meters, lng_meters)
      radius_meters = trunc(max_span_meters / 2)  # Radius is half the span
      
      # Apply reasonable limits for POI searches
      clamped_radius = min(max(radius_meters, 5_000), 200_000)  # 5km to 200km
      
      Logger.debug("📏 Calculated radius for #{city.name}: #{clamped_radius}m from bbox (#{lat_span}° × #{lng_span}°)")
      
      clamped_radius
    rescue
      error ->
        Logger.warning("⚠️ Failed to calculate radius from bbox for #{city.name}: #{inspect(error)}")
        nil
    end
  end
end