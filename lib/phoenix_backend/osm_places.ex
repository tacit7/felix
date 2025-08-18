# OpenStreetMap Places Service
# Free nearby places search using Overpass API with intelligent caching

defmodule RouteWiseApi.OSMPlaces do
  @moduledoc """
  Service for searching nearby places using OpenStreetMap Overpass API.
  
  Provides free unlimited searches with intelligent caching to reduce API calls
  and improve performance. Results are normalized to match Google Places format
  for seamless integration.
  
  ## Features
  - 100% free unlimited searches
  - Intelligent caching by geographic regions
  - Normalized data format compatible with existing system
  - Multiple OSM tag categories (amenities, tourism, shops, etc.)
  - Fallback to multiple Overpass API servers
  """
  
  require Logger
  alias RouteWiseApi.{Places, Repo}
  alias RouteWiseApi.Places.Place

  # Overpass API servers (in order of preference)
  @overpass_servers [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter", 
    "https://overpass.openstreetmap.ru/api/interpreter"
  ]

  # Cache TTL for OSM results (24 hours - OSM data doesn't change frequently)
  @cache_ttl_hours 24

  @doc """
  Search for nearby places using OpenStreetMap data.
  
  ## Parameters
  - lat: Latitude coordinate
  - lng: Longitude coordinate  
  - radius: Search radius in meters (default: 2000, max: 10000)
  - categories: List of place categories to search (default: all)
  - limit: Maximum results (default: 50)
  
  ## Categories
  - "restaurant" - Restaurants, cafes, bars
  - "accommodation" - Hotels, hostels, B&Bs
  - "attraction" - Tourist attractions, museums
  - "shopping" - Shops, malls, markets
  - "service" - Banks, pharmacies, services
  - "all" - All categories
  
  ## Examples
      iex> search_nearby(18.2357, -66.0328, 5000, ["restaurant", "attraction"])
      {:ok, [%{name: "...", category: "restaurant", ...}]}
  """
  def search_nearby(lat, lng, radius \\ 2000, categories \\ ["all"], limit \\ 50) do
    # Validate inputs
    with :ok <- validate_coordinates(lat, lng),
         :ok <- validate_radius(radius),
         {:ok, normalized_categories} <- normalize_categories(categories) do
      
      # Check cache first
      cache_key = build_cache_key(lat, lng, radius, normalized_categories)
      
      case get_cached_results(cache_key) do
        {:ok, cached_places} ->
          Logger.info("🎯 OSM cache hit for #{lat}, #{lng} (#{length(cached_places)} places)")
          {:ok, Enum.take(cached_places, limit)}
          
        :cache_miss ->
          # Fetch from OSM and cache results
          fetch_and_cache_osm_places(lat, lng, radius, normalized_categories, limit, cache_key)
      end
    end
  end

  @doc """
  Search for places by category near a location.
  Optimized for specific category searches with targeted OSM queries.
  """
  def search_by_category(lat, lng, category, radius \\ 2000, limit \\ 30) do
    search_nearby(lat, lng, radius, [category], limit)
  end

  @doc """
  Get statistics about OSM data coverage for a location.
  Useful for determining data quality and coverage.
  """
  def get_coverage_stats(lat, lng, radius \\ 5000) do
    categories = ["restaurant", "accommodation", "attraction", "shopping", "service"]
    
    stats = Enum.map(categories, fn category ->
      case search_nearby(lat, lng, radius, [category], 100) do
        {:ok, places} -> {category, length(places)}
        {:error, _} -> {category, 0}
      end
    end)
    
    total_places = Enum.reduce(stats, 0, fn {_cat, count}, acc -> acc + count end)
    
    %{
      total_places: total_places,
      categories: Map.new(stats),
      coverage_area: "#{radius}m radius",
      data_source: "OpenStreetMap",
      last_updated: DateTime.utc_now()
    }
  end

  # Private implementation functions

  defp validate_coordinates(lat, lng) do
    cond do
      not is_number(lat) or lat < -90 or lat > 90 ->
        {:error, "Invalid latitude: must be between -90 and 90"}
      not is_number(lng) or lng < -180 or lng > 180 ->
        {:error, "Invalid longitude: must be between -180 and 180"}
      true ->
        :ok
    end
  end

  defp validate_radius(radius) do
    cond do
      not is_integer(radius) or radius < 100 ->
        {:error, "Radius too small: minimum 100 meters"}
      radius > 10_000 ->
        {:error, "Radius too large: maximum 10,000 meters"}
      true ->
        :ok
    end
  end

  defp normalize_categories(categories) when is_list(categories) do
    valid_categories = ["restaurant", "accommodation", "attraction", "shopping", "service", "all"]
    
    normalized = Enum.filter(categories, fn cat -> 
      cat in valid_categories 
    end)
    
    case normalized do
      [] -> {:ok, ["all"]}  # Default to all if no valid categories
      cats -> {:ok, cats}
    end
  end

  defp normalize_categories(_), do: {:ok, ["all"]}

  defp build_cache_key(lat, lng, radius, categories) do
    # Round coordinates to reduce cache fragmentation while maintaining accuracy
    rounded_lat = Float.round(lat, 4)  # ~11m accuracy
    rounded_lng = Float.round(lng, 4)
    
    categories_str = Enum.sort(categories) |> Enum.join(",")
    "osm:#{rounded_lat},#{rounded_lng}:#{radius}:#{categories_str}"
  end

  defp get_cached_results(cache_key) do
    # Use the existing caching system for OSM results
    case get_cache_backend().get(cache_key) do
      {:ok, cached_places} ->
        Logger.debug("🎯 OSM cache hit: #{cache_key}")
        {:ok, cached_places}
      :error ->
        Logger.debug("🔍 OSM cache miss: #{cache_key}")
        :cache_miss
    end
  rescue
    error ->
      Logger.warning("⚠️  OSM cache error: #{Exception.message(error)}")
      :cache_miss
  end

  defp fetch_and_cache_osm_places(lat, lng, radius, categories, limit, cache_key) do
    Logger.info("🗺️  Fetching OSM places for #{lat}, #{lng} (#{radius}m)")
    
    case fetch_from_overpass(lat, lng, radius, categories) do
      {:ok, osm_data} ->
        # Process and normalize OSM data
        places = process_osm_results(osm_data, lat, lng)
        
        # Cache results in database
        cache_osm_places(places, cache_key)
        
        Logger.info("✅ OSM search success: #{length(places)} places found")
        {:ok, Enum.take(places, limit)}
        
      {:error, reason} ->
        Logger.error("❌ OSM search failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_from_overpass(lat, lng, radius, categories) do
    query = build_overpass_query(lat, lng, radius, categories)
    
    # Try each server until one works
    Enum.reduce_while(@overpass_servers, {:error, :all_servers_failed}, fn server, _acc ->
      case execute_overpass_query(server, query) do
        {:ok, result} -> {:halt, {:ok, result}}
        {:error, _reason} -> {:cont, {:error, :server_failed}}
      end
    end)
  end

  defp build_overpass_query(lat, lng, radius, categories) do
    # Build OSM tag filters based on categories
    tag_filters = build_tag_filters(categories)
    
    """
    [out:json][timeout:30];
    (
      #{tag_filters}
    );
    out geom meta;
    """
    |> String.replace("{{LAT}}", to_string(lat))
    |> String.replace("{{LNG}}", to_string(lng))
    |> String.replace("{{RADIUS}}", to_string(radius))
  end

  defp build_tag_filters(categories) do
    if "all" in categories do
      # All major POI categories
      """
      node["amenity"](around:{{RADIUS}},{{LAT}},{{LNG}});
      way["amenity"](around:{{RADIUS}},{{LAT}},{{LNG}});
      node["tourism"](around:{{RADIUS}},{{LAT}},{{LNG}});
      way["tourism"](around:{{RADIUS}},{{LAT}},{{LNG}});
      node["shop"](around:{{RADIUS}},{{LAT}},{{LNG}});
      way["shop"](around:{{RADIUS}},{{LAT}},{{LNG}});
      node["leisure"](around:{{RADIUS}},{{LAT}},{{LNG}});
      way["leisure"](around:{{RADIUS}},{{LAT}},{{LNG}});
      """
    else
      # Category-specific filters
      Enum.map(categories, &category_to_osm_filter/1) |> Enum.join("\n")
    end
  end

  defp category_to_osm_filter("restaurant") do
    """
    node["amenity"~"^(restaurant|cafe|bar|pub|fast_food|food_court)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    way["amenity"~"^(restaurant|cafe|bar|pub|fast_food|food_court)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    """
  end

  defp category_to_osm_filter("accommodation") do
    """
    node["tourism"~"^(hotel|hostel|guest_house|motel|apartment)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    way["tourism"~"^(hotel|hostel|guest_house|motel|apartment)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    """
  end

  defp category_to_osm_filter("attraction") do
    """
    node["tourism"~"^(attraction|museum|gallery|zoo|theme_park|viewpoint)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    way["tourism"~"^(attraction|museum|gallery|zoo|theme_park|viewpoint)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    node["leisure"~"^(park|garden|nature_reserve)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    way["leisure"~"^(park|garden|nature_reserve)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    """
  end

  defp category_to_osm_filter("shopping") do
    """
    node["shop"](around:{{RADIUS}},{{LAT}},{{LNG}});
    way["shop"](around:{{RADIUS}},{{LAT}},{{LNG}});
    node["amenity"="marketplace"](around:{{RADIUS}},{{LAT}},{{LNG}});
    way["amenity"="marketplace"](around:{{RADIUS}},{{LAT}},{{LNG}});
    """
  end

  defp category_to_osm_filter("service") do
    """
    node["amenity"~"^(bank|atm|pharmacy|hospital|clinic|police|post_office)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    way["amenity"~"^(bank|atm|pharmacy|hospital|clinic|police|post_office)"](around:{{RADIUS}},{{LAT}},{{LNG}});
    """
  end

  defp category_to_osm_filter(_), do: ""

  defp execute_overpass_query(server, query) do
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    
    case HTTPoison.post(server, "data=#{URI.encode(query)}", headers, timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"elements" => elements}} -> {:ok, elements}
          {:ok, _} -> {:error, :invalid_response}
          {:error, _} -> {:error, :json_decode_failed}
        end
        
      {:ok, %{status_code: status}} ->
        {:error, {:http_error, status}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp process_osm_results(elements, center_lat, center_lng) do
    elements
    |> Enum.filter(&has_required_fields/1)
    |> Enum.map(&normalize_osm_element(&1, center_lat, center_lng))
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort_by(& &1.distance)
  end

  defp has_required_fields(element) do
    Map.has_key?(element, "tags") and 
    Map.has_key?(element["tags"], "name") and
    (Map.has_key?(element, "lat") or Map.has_key?(element, "center"))
  end

  defp normalize_osm_element(element, center_lat, center_lng) do
    tags = element["tags"]
    name = tags["name"]
    
    # Get coordinates (handle both nodes and ways)
    {lat, lng} = get_element_coordinates(element)
    
    if lat && lng do
      # Calculate distance from search center
      distance = haversine_distance(center_lat, center_lng, lat, lng)
      
      %{
        id: "osm_#{element["type"]}_#{element["id"]}",
        name: name,
        category: determine_category(tags),
        place_types: extract_place_types(tags),
        lat: lat,
        lng: lng,
        distance: distance,
        rating: generate_rating(tags),
        address: build_address(tags),
        phone: tags["phone"],
        website: tags["website"],
        opening_hours: tags["opening_hours"],
        source: "openstreetmap",
        osm_id: element["id"],
        osm_type: element["type"]
      }
    end
  end

  defp get_element_coordinates(%{"lat" => lat, "lon" => lng}), do: {lat, lng}
  defp get_element_coordinates(%{"center" => %{"lat" => lat, "lon" => lng}}), do: {lat, lng}
  defp get_element_coordinates(_), do: {nil, nil}

  defp determine_category(tags) do
    cond do
      tags["amenity"] in ["restaurant", "cafe", "bar", "pub", "fast_food"] -> "restaurant"
      tags["tourism"] in ["hotel", "hostel", "guest_house"] -> "accommodation"
      tags["tourism"] in ["attraction", "museum", "gallery"] -> "attraction"
      tags["shop"] -> "shopping"
      tags["amenity"] in ["bank", "pharmacy", "hospital"] -> "service"
      true -> "other"
    end
  end

  defp extract_place_types(tags) do
    types = []
    
    types = if tags["amenity"], do: [tags["amenity"] | types], else: types
    types = if tags["tourism"], do: [tags["tourism"] | types], else: types
    types = if tags["shop"], do: [tags["shop"] | types], else: types
    types = if tags["leisure"], do: [tags["leisure"] | types], else: types
    
    Enum.reverse(types)
  end

  defp generate_rating(tags) do
    # Generate estimated rating based on available data
    base_rating = 4.0
    
    # Boost for complete information
    rating_boost = 0
    rating_boost = if tags["phone"], do: rating_boost + 0.2, else: rating_boost
    rating_boost = if tags["website"], do: rating_boost + 0.2, else: rating_boost
    rating_boost = if tags["opening_hours"], do: rating_boost + 0.1, else: rating_boost
    
    min(5.0, base_rating + rating_boost)
  end

  defp build_address(tags) do
    parts = [
      tags["addr:housenumber"],
      tags["addr:street"],
      tags["addr:city"],
      tags["addr:postcode"]
    ] |> Enum.filter(&(&1 != nil))
    
    case parts do
      [] -> nil
      address_parts -> Enum.join(address_parts, " ")
    end
  end

  defp cache_osm_places(places, cache_key) do
    try do
      # Cache OSM results for 24 hours
      cache_ttl_ms = @cache_ttl_hours * 60 * 60 * 1000
      
      case get_cache_backend().put(cache_key, places, cache_ttl_ms) do
        :ok ->
          Logger.info("💾 Cached #{length(places)} OSM places with key: #{cache_key}")
        {:error, reason} ->
          Logger.warning("⚠️  Failed to cache OSM places: #{inspect(reason)}")
      end
    rescue
      error ->
        Logger.error("❌ OSM caching error: #{Exception.message(error)}")
    end
  end

  defp format_osm_place(_place) do
    # Not used since we're not implementing database caching yet
    %{}
  end

  # Get the caching backend from the existing caching system
  defp get_cache_backend do
    try do
      RouteWiseApi.Caching.backend()
    rescue
      _ -> RouteWiseApi.Caching.Backend.Memory
    end
  end

  # Haversine distance calculation
  defp haversine_distance(lat1, lng1, lat2, lng2) do
    r = 6371  # Earth's radius in kilometers
    
    dlat = :math.pi() * (lat2 - lat1) / 180
    dlng = :math.pi() * (lng2 - lng1) / 180
    
    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(:math.pi() * lat1 / 180) * :math.cos(:math.pi() * lat2 / 180) *
        :math.sin(dlng / 2) * :math.sin(dlng / 2)
    
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    
    r * c * 1000  # Return distance in meters
  end
end