defmodule RouteWiseApi.LocationIQ do
  @moduledoc """
  LocationIQ API client for city autocomplete with rate limiting and circuit breaker protection.

  Provides robust city search functionality with:
  - Rate limiting to prevent API quota exhaustion
  - Circuit breaker pattern for fault tolerance
  - Intelligent fallback to cached data during outages
  - Comprehensive error handling and retry logic

  This client integrates with the caching system to provide graceful
  degradation when the LocationIQ API is unavailable or rate limited.
  """

  alias RouteWiseApi.LocationIQ.{RateLimiter, CircuitBreaker}
  alias RouteWiseApi.Places
  require Logger

  @base_url "https://us1.locationiq.com/v1"
  @timeout 5000
  @service_name "autocomplete"

  @doc """
  General geocoding for any location type using LocationIQ search API.

  Provides robust geocoding for addresses, landmarks, POIs, and other locations
  with the same protection mechanisms as city autocomplete.

  ## Parameters
  - query: Search string (required)
  - opts: Keyword list of options
    - :limit - Maximum results (default: 10)
    - :countries - Country codes (default: "us,ca,mx")
    - :viewbox - Geographic bounding box (optional)
    - :user_id - User identifier for rate limiting (optional)

  ## Examples
      iex> geocode("1600 Pennsylvania Avenue, Washington DC")
      {:ok, [%{lat: 38.8977, lon: -77.0365, display_name: "White House", ...}]}

      iex> geocode("Golden Gate Bridge", limit: 1)
      {:ok, [%{lat: 37.8199, lon: -122.4783, display_name: "Golden Gate Bridge", ...}]}

  ## Returns
  - `{:ok, locations}` - List of formatted location maps from API
  - `{:error, reason}` - Error with reason and optional cached fallback
  """
  def geocode(query, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "global")

    # Create fallback function that uses cached data
    fallback_fn = fn ->
      get_cached_fallback(query, opts)
    end

    # Use circuit breaker with rate limiting protection
    CircuitBreaker.call(
      @service_name,
      fn ->
        make_geocode_request(query, opts, user_id)
      end,
      fallback_fn
    )
  end

  @doc """
  Search for cities using LocationIQ autocomplete API with protection.

  Integrates rate limiting and circuit breaker protection to provide
  reliable city search with graceful fallback to cached data when
  the API is unavailable or rate limited.

  ## Parameters
  - query: Search string (required)
  - opts: Keyword list of options
    - :limit - Maximum results (default: 10)
    - :countries - Country codes (default: "us,ca,mx")
    - :viewbox - Geographic bounding box (optional)
    - :user_id - User identifier for rate limiting (optional)

  ## Examples
      iex> autocomplete_cities("san francisco", limit: 5)
      {:ok, [%{name: "San Francisco", country: "United States", ...}]}

      iex> autocomplete_cities("query", user_id: "user_123") # rate limited
      {:error, :rate_limited, cached_results}

      iex> autocomplete_cities("query") # circuit breaker open
      {:error, :circuit_open, cached_results}

  ## Returns
  - `{:ok, cities}` - List of formatted city maps from API
  - `{:error, reason}` - Error with reason and optional cached fallback
  - `{:error, reason, fallback}` - Error with cached results as fallback
  """
  def autocomplete_cities(query, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "global")

    # Create fallback function that uses cached data
    fallback_fn = fn ->
      get_cached_fallback(query, opts)
    end

    # Use circuit breaker with rate limiting protection
    CircuitBreaker.call(
      @service_name,
      fn ->
        make_rate_limited_request(query, opts, user_id)
      end,
      fallback_fn
    )
  end

  @doc """
  Get current API status including rate limits and circuit breaker state.

  Useful for monitoring and debugging API health.

  ## Examples
      iex> get_api_status()
      %{
        circuit_breaker: %{status: :closed, failure_count: 0},
        rate_limits: %{per_second: %{tokens: 2, capacity: 2}}
      }
  """
  def get_api_status(user_id \\ "global") do
    %{
      circuit_breaker: CircuitBreaker.get_state(@service_name),
      rate_limits: RateLimiter.get_status(@service_name, user_id)
    }
  end

  @doc """
  Reset protection systems for testing or emergency situations.
  """
  def reset_protection() do
    CircuitBreaker.reset(@service_name)
    RateLimiter.reset_limits(@service_name)
  end

  @doc """
  Get detailed place information using LocationIQ Places API.
  
  Provides rich place details including descriptions, categories, 
  opening hours, and other metadata for POIs.

  ## Parameters
  - place_id: LocationIQ place ID (required)
  - opts: Options including :user_id for rate limiting

  ## Examples
      iex> get_place_details("12345")
      {:ok, %{
        name: "Central Park",
        description: "Large public park in Manhattan",
        category: "park",
        opening_hours: %{...},
        ...
      }}

  ## Returns
  - `{:ok, place_details}` - Formatted place details from API
  - `{:error, reason}` - Error with descriptive reason
  """
  def get_place_details(place_id, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "global")
    
    fallback_fn = fn ->
      Logger.warning("LocationIQ place details fallback - returning minimal data")
      {:error, "Place details unavailable", %{}}
    end

    CircuitBreaker.call(
      @service_name,
      fn ->
        make_place_details_request(place_id, opts, user_id)
      end,
      fallback_fn
    )
  end

  @doc """
  Search for places by name and location using LocationIQ Places API.
  
  Useful for finding places with rich descriptions and metadata.

  ## Parameters
  - query: Search query (name, category, etc.)
  - location: Coordinates %{lat: lat, lng: lng} (optional)
  - opts: Options including :limit, :radius, :user_id

  ## Examples
      iex> search_places("restaurant", %{lat: 30.27, lng: -97.74}, limit: 10)
      {:ok, [%{name: "Restaurant Name", description: "...", ...}]}

  ## Returns
  - `{:ok, places}` - List of places with detailed information
  - `{:error, reason}` - Error with descriptive reason
  """
  def search_places(query, location \\ nil, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "global")
    
    fallback_fn = fn ->
      Logger.warning("LocationIQ places search fallback - returning empty results")
      {:ok, []}
    end

    CircuitBreaker.call(
      @service_name,
      fn ->
        make_places_search_request(query, location, opts, user_id)
      end,
      fallback_fn
    )
  end

  @doc """
  Calculate route directions between two points using LocationIQ Directions API.

  Provides comprehensive routing with:
  - Real road-based distance and duration
  - Route polyline geometry for map drawing
  - Turn-by-turn directions
  - Waypoint support

  ## Parameters
  - start_coords: Map with :lat and :lng keys
  - end_coords: Map with :lat and :lng keys  
  - opts: Keyword list of options
    - :waypoints - List of intermediate waypoint coordinates (optional)
    - :profile - Routing profile: "driving" (default), "walking", "cycling"
    - :alternatives - Number of alternative routes (default: 0)
    - :steps - Include turn-by-turn directions (default: true)
    - :user_id - User identifier for rate limiting (optional)

  ## Examples
      iex> get_directions(%{lat: 30.2711, lng: -97.7437}, %{lat: 32.7763, lng: -96.7969})
      {:ok, %{
        distance: 314.2,
        duration: 11340,
        polyline: "...",
        steps: [%{instruction: "Head north", distance: 245, duration: 30}, ...]
      }}

      iex> get_directions(start, end, waypoints: [%{lat: 31.5494, lng: -97.1467}])
      {:ok, route_with_waypoint}

  ## Returns
  - `{:ok, route}` - Formatted route data with distance, duration, polyline, steps
  - `{:error, reason}` - Error with descriptive reason
  """
  def get_directions(start_coords, end_coords, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "global")
    
    fallback_fn = fn ->
      Logger.warning("LocationIQ directions fallback - returning estimated route")
      get_estimated_route_fallback(start_coords, end_coords)
    end

    CircuitBreaker.call(
      @service_name,
      fn ->
        make_directions_request(start_coords, end_coords, opts, user_id)
      end,
      fallback_fn
    )
  end

  @doc """
  Calculate route matrix (distances and durations) between multiple points.

  Useful for optimization and finding closest POIs to a route.

  ## Parameters
  - sources: List of coordinate maps with :lat and :lng
  - destinations: List of coordinate maps with :lat and :lng (optional, uses sources if nil)
  - opts: Options including :profile, :user_id

  ## Examples
      iex> get_route_matrix([%{lat: 30.27, lng: -97.74}], [%{lat: 32.78, lng: -96.80}])
      {:ok, %{
        distances: [[314200]], # meters
        durations: [[11340]]   # seconds
      }}
  """
  def get_route_matrix(sources, destinations \\ nil, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "global")
    destinations = destinations || sources
    
    fallback_fn = fn ->
      Logger.warning("LocationIQ matrix fallback - returning estimated distances")
      get_estimated_matrix_fallback(sources, destinations)
    end

    CircuitBreaker.call(
      @service_name,
      fn ->
        make_matrix_request(sources, destinations, opts, user_id)
      end,
      fallback_fn
    )
  end

  # Private functions - Places API Implementation

  defp make_place_details_request(place_id, opts, user_id) do
    case RateLimiter.check_rate_limit(@service_name, user_id) do
      {:ok, _remaining} ->
        make_place_details_api_request(place_id, opts)

      {:error, :rate_limited, _retry_after} ->
        Logger.warning("LocationIQ place details rate limit exceeded for #{user_id}")
        raise "Rate limit exceeded"
    end
  end

  defp make_place_details_api_request(place_id, _opts) do
    params = %{
      key: get_api_key(),
      format: "json",
      addressdetails: 1,
      extratags: 1,
      namedetails: 1
    }

    url = "#{@base_url}/details"

    case HTTPoison.get(url, [], params: Map.put(params, :place_id, place_id), timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, place_data} ->
            formatted_place = format_place_details_response(place_data)
            Logger.debug("LocationIQ place details success for place_id: #{place_id}")
            {:ok, formatted_place}

          {:error, _} ->
            Logger.error("LocationIQ place details JSON decode failed for place_id: #{place_id}")
            raise "Invalid response format"
        end

      {:ok, %{status_code: status}} when status >= 400 ->
        Logger.error("LocationIQ place details API error (#{status}) for place_id: #{place_id}")
        raise "LocationIQ API error: #{status}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("LocationIQ place details request failed for place_id #{place_id}: #{reason}")
        raise %HTTPoison.Error{reason: reason}
    end
  end

  defp make_places_search_request(query, location, opts, user_id) do
    case RateLimiter.check_rate_limit(@service_name, user_id) do
      {:ok, _remaining} ->
        make_places_search_api_request(query, location, opts)

      {:error, :rate_limited, _retry_after} ->
        Logger.warning("LocationIQ places search rate limit exceeded for #{user_id}")
        raise "Rate limit exceeded"
    end
  end

  defp make_places_search_api_request(query, location, opts) do
    params = build_places_search_params(query, location, opts)

    case HTTPoison.get("#{@base_url}/search", [], params: params, timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, results} ->
            formatted_places = format_places_search_results(results)
            Logger.debug("LocationIQ places search success: #{length(formatted_places)} places for '#{query}'")
            {:ok, formatted_places}

          {:error, _} ->
            Logger.error("LocationIQ places search JSON decode failed for query '#{query}'")
            raise "Invalid response format"
        end

      {:ok, %{status_code: status}} when status >= 400 ->
        Logger.error("LocationIQ places search API error (#{status}) for query '#{query}'")
        raise "LocationIQ API error: #{status}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("LocationIQ places search request failed for query '#{query}': #{reason}")
        raise %HTTPoison.Error{reason: reason}
    end
  end

  defp build_places_search_params(query, location, opts) do
    base_params = %{
      key: get_api_key(),
      q: query,
      limit: Keyword.get(opts, :limit, 10),
      countrycodes: Keyword.get(opts, :countries, "us,ca,mx"),
      addressdetails: 1,
      extratags: 1,
      namedetails: 1,
      format: "json"
    }

    # Add location-based search if coordinates provided
    params_with_location = case location do
      %{lat: lat, lng: lng} when is_number(lat) and is_number(lng) ->
        radius = Keyword.get(opts, :radius, 10000) # 10km default
        base_params
        |> Map.put(:lat, lat)
        |> Map.put(:lon, lng)
        |> Map.put(:radius, radius)
      _ -> 
        base_params
    end

    case Keyword.get(opts, :viewbox) do
      nil -> params_with_location
      viewbox -> Map.put(params_with_location, :viewbox, viewbox)
    end
  end

  defp format_place_details_response(place_data) do
    %{
      place_id: place_data["place_id"],
      name: place_data["display_name"] || extract_name_from_address(place_data),
      description: extract_place_description(place_data),
      lat: parse_coordinate(place_data["lat"]),
      lng: parse_coordinate(place_data["lon"]),
      category: determine_place_category(place_data),
      address: place_data["display_name"],
      extratags: place_data["extratags"] || %{},
      address_components: place_data["address"] || %{},
      importance: place_data["importance"],
      place_type: place_data["type"],
      class: place_data["class"]
    }
  end

  defp format_places_search_results(results) do
    Enum.map(results, &format_place_details_response/1)
  end

  defp extract_name_from_address(place_data) do
    address = place_data["address"] || %{}
    address["name"] || address["amenity"] || address["shop"] || 
    address["tourism"] || place_data["display_name"] || "Unknown Place"
  end

  defp extract_place_description(place_data) do
    extratags = place_data["extratags"] || %{}
    address = place_data["address"] || %{}
    
    # Try to build a meaningful description from available data
    cond do
      # Check for Wikipedia description
      extratags["wikipedia"] ->
        "Learn more: #{extratags["wikipedia"]}"
      
      # Check for website
      extratags["website"] ->
        category = determine_place_category(place_data)
        "#{String.capitalize(category)} with website: #{extratags["website"]}"
      
      # Check for amenity type with details
      address["amenity"] ->
        amenity = address["amenity"]
        cuisine = extratags["cuisine"] || ""
        if cuisine != "" do
          "#{String.capitalize(amenity)} serving #{cuisine} cuisine"
        else
          "#{String.capitalize(String.replace(amenity, "_", " "))}"
        end
      
      # Check for shop type
      address["shop"] ->
        "#{String.capitalize(String.replace(address["shop"], "_", " "))} shop"
      
      # Check for tourism type
      address["tourism"] ->
        "Tourist attraction: #{String.capitalize(String.replace(address["tourism"], "_", " "))}"
      
      # Fallback to place type
      place_data["type"] ->
        "#{String.capitalize(String.replace(place_data["type"], "_", " "))}"
      
      # Final fallback
      true ->
        "Point of interest"
    end
  end

  defp determine_place_category(place_data) do
    address = place_data["address"] || %{}
    class = place_data["class"]
    
    cond do
      address["amenity"] == "restaurant" or class == "amenity" -> "restaurant"
      address["amenity"] == "gas_station" or address["amenity"] == "fuel" -> "gas_station"  
      address["tourism"] or class == "tourism" -> "attraction"
      address["shop"] or class == "shop" -> "shopping"
      address["amenity"] == "lodging" or address["tourism"] == "hotel" -> "lodging"
      true -> "attraction"
    end
  end

  defp parse_coordinate(coord_string) when is_binary(coord_string) do
    case Float.parse(coord_string) do
      {float_val, _} -> float_val
      :error -> nil
    end
  end
  defp parse_coordinate(coord) when is_number(coord), do: coord
  defp parse_coordinate(_), do: nil

  # Private functions - Routing Implementation

  defp make_directions_request(start_coords, end_coords, opts, user_id) do
    case RateLimiter.check_rate_limit(@service_name, user_id) do
      {:ok, _remaining} ->
        make_directions_api_request(start_coords, end_coords, opts)

      {:error, :rate_limited, _retry_after} ->
        Logger.warning("LocationIQ directions rate limit exceeded for #{user_id}")
        raise "Rate limit exceeded"
    end
  end

  defp make_directions_api_request(start_coords, end_coords, opts) do
    coordinates = build_coordinates_string(start_coords, end_coords, opts[:waypoints])
    profile = Keyword.get(opts, :profile, "driving")
    
    params = %{
      key: get_api_key(),
      steps: Keyword.get(opts, :steps, true),
      geometries: "geojson",
      overview: "full",
      alternatives: Keyword.get(opts, :alternatives, 0)
    }

    url = "#{@base_url}/directions/#{profile}/#{coordinates}"
    
    case HTTPoison.get(url, [], params: params, timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"routes" => [route | _]} = response} ->
            formatted_route = format_route_response(route)
            
            Logger.debug("LocationIQ directions success: #{formatted_route.distance}km, #{formatted_route.duration}s")
            
            {:ok, formatted_route}

          {:ok, %{"routes" => []}} ->
            Logger.warning("LocationIQ directions returned no routes")
            raise "No route found"

          {:error, _} ->
            Logger.error("LocationIQ directions JSON decode failed")
            raise "Invalid response format"
        end

      {:ok, %{status_code: 429}} ->
        Logger.warning("LocationIQ directions rate limited (429)")
        raise "LocationIQ API error: 429"

      {:ok, %{status_code: status}} when status >= 500 ->
        Logger.error("LocationIQ directions server error (#{status})")
        raise "LocationIQ API error: #{status}"

      {:ok, %{status_code: status}} ->
        Logger.warning("LocationIQ directions client error (#{status})")
        raise "LocationIQ API error: #{status}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("LocationIQ directions request failed: #{reason}")
        raise %HTTPoison.Error{reason: reason}
    end
  end

  defp make_matrix_request(sources, destinations, opts, user_id) do
    case RateLimiter.check_rate_limit(@service_name, user_id) do
      {:ok, _remaining} ->
        make_matrix_api_request(sources, destinations, opts)

      {:error, :rate_limited, _retry_after} ->
        Logger.warning("LocationIQ matrix rate limit exceeded for #{user_id}")
        raise "Rate limit exceeded"
    end
  end

  defp make_matrix_api_request(sources, destinations, opts) do
    profile = Keyword.get(opts, :profile, "driving")
    
    # Format coordinates for matrix API
    source_coords = Enum.map(sources, fn coord -> "#{coord.lng},#{coord.lat}" end)
    dest_coords = Enum.map(destinations, fn coord -> "#{coord.lng},#{coord.lat}" end)
    
    params = %{
      key: get_api_key(),
      sources: Enum.join(source_coords, ";"),
      destinations: Enum.join(dest_coords, ";")
    }

    url = "#{@base_url}/matrix/#{profile}"
    
    case HTTPoison.get(url, [], params: params, timeout: @timeout * 2) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, response} ->
            formatted_matrix = format_matrix_response(response)
            
            Logger.debug("LocationIQ matrix success: #{length(sources)}x#{length(destinations)} matrix")
            
            {:ok, formatted_matrix}

          {:error, _} ->
            Logger.error("LocationIQ matrix JSON decode failed")
            raise "Invalid response format"
        end

      {:ok, %{status_code: status}} when status >= 400 ->
        Logger.error("LocationIQ matrix API error (#{status})")
        raise "LocationIQ API error: #{status}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("LocationIQ matrix request failed: #{reason}")
        raise %HTTPoison.Error{reason: reason}
    end
  end

  defp build_coordinates_string(start_coords, end_coords, waypoints \\ nil) do
    coords = [start_coords]
    coords = if waypoints, do: coords ++ waypoints, else: coords
    coords = coords ++ [end_coords]
    
    coords
    |> Enum.map(fn coord -> "#{coord.lng},#{coord.lat}" end)
    |> Enum.join(";")
  end

  defp format_route_response(route) do
    # Extract route geometry (polyline)
    polyline = case route["geometry"] do
      %{"coordinates" => coordinates} -> encode_polyline(coordinates)
      _ -> nil
    end

    # Format turn-by-turn steps
    steps = case route["legs"] do
      [leg | _] when is_map(leg) ->
        leg
        |> Map.get("steps", [])
        |> Enum.map(&format_route_step/1)
      _ -> []
    end

    %{
      distance: route["distance"] / 1000.0,  # Convert meters to km
      duration: route["duration"],           # Seconds
      polyline: polyline,
      steps: steps,
      bbox: route["bbox"],
      raw_geometry: route["geometry"]
    }
  end

  defp format_route_step(step) do
    %{
      instruction: step["maneuver"]["instruction"] || "Continue",
      distance: step["distance"],
      duration: step["duration"],
      type: step["maneuver"]["type"],
      modifier: step["maneuver"]["modifier"]
    }
  end

  defp format_matrix_response(response) do
    %{
      distances: response["distances"] || [],  # 2D array in meters
      durations: response["durations"] || []   # 2D array in seconds
    }
  end

  # Simple polyline encoding for coordinates
  defp encode_polyline(coordinates) do
    # For now, return coordinates as JSON string
    # You could implement proper polyline encoding here if needed
    Jason.encode!(coordinates)
  end

  # Fallback functions for when API is unavailable
  defp get_estimated_route_fallback(start_coords, end_coords) do
    # Calculate straight-line distance and estimate driving time
    distance_km = calculate_haversine_distance(start_coords, end_coords)
    
    # Rough estimation: driving adds ~40% to straight-line distance
    estimated_distance = distance_km * 1.4
    
    # Rough estimation: average 80 km/h including stops
    estimated_duration = (estimated_distance / 80.0) * 3600
    
    %{
      distance: estimated_distance,
      duration: round(estimated_duration),
      polyline: nil,
      steps: [],
      estimated: true,
      fallback_reason: "LocationIQ API unavailable"
    }
  end

  defp get_estimated_matrix_fallback(sources, destinations) do
    distances = for source <- sources do
      for destination <- destinations do
        distance_km = calculate_haversine_distance(source, destination)
        round(distance_km * 1400)  # Convert to meters with driving factor
      end
    end
    
    durations = for distance_row <- distances do
      for distance <- distance_row do
        round(distance / 1000.0 / 80.0 * 3600)  # Estimate at 80 km/h
      end
    end

    %{
      distances: distances,
      durations: durations,
      estimated: true,
      fallback_reason: "LocationIQ API unavailable"
    }
  end

  defp calculate_haversine_distance(coord1, coord2) do
    # Haversine formula for great circle distance
    lat1_rad = coord1.lat * :math.pi() / 180
    lat2_rad = coord2.lat * :math.pi() / 180
    delta_lat = (coord2.lat - coord1.lat) * :math.pi() / 180
    delta_lng = (coord2.lng - coord1.lng) * :math.pi() / 180

    a = :math.sin(delta_lat / 2) * :math.sin(delta_lat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(delta_lng / 2) * :math.sin(delta_lng / 2)
    
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    
    6371.0 * c  # Earth's radius in kilometers
  end

  # Private functions - Geocoding Implementation

  defp make_rate_limited_request(query, opts, user_id) do
    case RateLimiter.check_rate_limit(@service_name, user_id) do
      {:ok, _remaining} ->
        make_api_request(query, opts)

      {:error, :rate_limited, retry_after} ->
        Logger.warning("LocationIQ rate limit exceeded for #{user_id}, retry in #{retry_after}s")
        raise "Rate limit exceeded, retry after #{retry_after} seconds"
    end
  end

  defp make_geocode_request(query, opts, user_id) do
    case RateLimiter.check_rate_limit(@service_name, user_id) do
      {:ok, _remaining} ->
        make_geocode_api_request(query, opts)

      {:error, :rate_limited, _retry_after} ->
        Logger.warning("LocationIQ rate limit exceeded for #{user_id}")
        raise "Rate limit exceeded"
    end
  end

  defp make_geocode_api_request(query, opts) do
    params = build_geocode_params(query, opts)

    case HTTPoison.get("#{@base_url}/search", [], params: params, timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, results} ->
            formatted_results = format_geocode_results(results)

            Logger.debug(
              "LocationIQ geocode success: #{length(formatted_results)} locations for '#{query}'"
            )

            {:ok, formatted_results}

          {:error, _} ->
            Logger.error("LocationIQ JSON decode failed for geocode query '#{query}'")
            raise "Invalid response format"
        end

      {:ok, %{status_code: 429}} ->
        Logger.warning("LocationIQ rate limited (429) for geocode query '#{query}'")
        raise "LocationIQ API error: 429"

      {:ok, %{status_code: status}} when status >= 500 ->
        Logger.error("LocationIQ server error (#{status}) for geocode query '#{query}'")
        raise "LocationIQ API error: #{status}"

      {:ok, %{status_code: status}} ->
        Logger.warning("LocationIQ client error (#{status}) for geocode query '#{query}'")
        raise "LocationIQ API error: #{status}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("LocationIQ geocode request failed for query '#{query}': #{reason}")
        raise %HTTPoison.Error{reason: reason}
    end
  end

  defp make_api_request(query, opts) do
    params = build_autocomplete_params(query, opts)

    case HTTPoison.get("#{@base_url}/autocomplete", [], params: params, timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, results} ->
            formatted_results = format_city_results(results)

            Logger.debug(
              "LocationIQ API success: #{length(formatted_results)} cities for '#{query}'"
            )

            {:ok, formatted_results}

          {:error, _} ->
            Logger.error("LocationIQ JSON decode failed for query '#{query}'")
            raise "Invalid response format"
        end

      {:ok, %{status_code: 429}} ->
        Logger.warning("LocationIQ rate limited (429) for query '#{query}'")
        raise "LocationIQ API error: 429"

      {:ok, %{status_code: status}} when status >= 500 ->
        Logger.error("LocationIQ server error (#{status}) for query '#{query}'")
        raise "LocationIQ API error: #{status}"

      {:ok, %{status_code: status}} ->
        Logger.warning("LocationIQ client error (#{status}) for query '#{query}'")
        raise "LocationIQ API error: #{status}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("LocationIQ request failed for query '#{query}': #{reason}")
        raise %HTTPoison.Error{reason: reason}
    end
  end

  defp get_cached_fallback(query, opts) do
    # Try to get cached results from database
    normalized_query = Places.normalize_location_input(query)
    case Places.search_cities_in_db(query, normalized_query, opts) do
      [] ->
        Logger.info("No cached fallback available for query '#{query}'")
        []

      cached_cities ->
        Logger.info("Using #{length(cached_cities)} cached cities as fallback for '#{query}'")
        Places.format_city_results(cached_cities)
    end
  end

  defp build_geocode_params(query, opts) do
    base_params = %{
      key: get_api_key(),
      q: query,
      limit: Keyword.get(opts, :limit, 10),
      countrycodes: Keyword.get(opts, :countries, "us,ca,mx"),
      addressdetails: 1,
      format: "json"
    }

    case Keyword.get(opts, :viewbox) do
      nil -> base_params
      viewbox -> Map.put(base_params, :viewbox, viewbox)
    end
  end

  defp build_autocomplete_params(query, opts) do
    base_params = %{
      key: get_api_key(),
      q: query,
      limit: Keyword.get(opts, :limit, 10),
      countrycodes: Keyword.get(opts, :countries, "us,ca,mx"),
      addressdetails: 1,
      format: "json"
    }

    case Keyword.get(opts, :viewbox) do
      nil -> base_params
      viewbox -> Map.put(base_params, :viewbox, viewbox)
    end
  end

  defp format_geocode_results(results) do
    Enum.map(results, fn result ->
      %{
        place_id: result["place_id"],
        display_name: result["display_name"],
        lat: String.to_float(result["lat"]),
        lon: String.to_float(result["lon"]),
        type: result["type"],
        class: result["class"],
        importance: result["importance"],
        address: result["address"] || %{},
        city: extract_city(result),
        state: get_in(result, ["address", "state"]),
        country: get_in(result, ["address", "country"]),
        country_code: get_in(result, ["address", "country_code"])
      }
    end)
  end

  defp format_city_results(results) do
    Enum.map(results, fn result ->
      %{
        place_id: result["place_id"],
        display_name: result["display_name"],
        lat: String.to_float(result["lat"]),
        lon: String.to_float(result["lon"]),
        type: result["type"],
        city: extract_city(result),
        state: get_in(result, ["address", "state"]),
        country: get_in(result, ["address", "country"]),
        country_code: get_in(result, ["address", "country_code"])
      }
    end)
  end

  defp extract_city(%{"address" => address}) do
    address["city"] || address["town"] || address["village"] ||
      address["municipality"] || address["county"] || address["state_district"]
  end

  defp get_api_key do
    Application.get_env(:phoenix_backend, :location_iq)[:api_key] ||
      System.get_env("LOCATION_IQ_API_KEY") ||
      raise "LocationIQ API key not configured"
  end
end
