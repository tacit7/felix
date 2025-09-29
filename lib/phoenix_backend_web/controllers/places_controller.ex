defmodule RouteWiseApiWeb.PlacesController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.PlacesService
  alias RouteWiseApi.Places
  alias RouteWiseApi.AutocompleteService

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  Search for places by query and location.

  ## Parameters
  - query: Search query string (required)
  - lat: Latitude (required)
  - lng: Longitude (required)
  - radius: Search radius in meters (optional, default: 5000)
  - type: Place type filter (optional)

  ## Examples
  GET /api/places/search?query=restaurants&lat=37.7749&lng=-122.4194&radius=1000
  """
  def search(conn, params) do
    with {:ok, search_params} <- validate_search_params(params),
         {:ok, places} <- PlacesService.search_places(
           search_params.query,
           search_params.location,
           search_params.opts
         ) do
      cache_info = determine_cache_status(places, :search)
      render(conn, :search, places: places, cache_info: cache_info)
    end
  end

  @doc """
  Get detailed information about a specific place.

  ## Parameters
  - id: Google Place ID (required)

  ## Examples
  GET /api/places/details/ChIJN1t_tDeuEmsRUsoyG83frY4
  """
  def details(conn, %{"id" => google_place_id}) do
    with {:ok, place} <- PlacesService.get_place_details(google_place_id) do
      cache_info = determine_cache_status([place], :details)
      render(conn, :details, place: place, cache_info: cache_info)
    end
  end

  @doc """
  Smart autocomplete with automatic pattern detection.
  
  Intelligently detects input type and searches appropriate sources:
  - Numbers ("123 Main") → Address search
  - Short phrases ("Boston") → City + Place search
  - Business names ("Starbucks") → Place search
  - State/regions ("California") → Region search
  
  ## Parameters
  - input: Search query (required)
  - lat: Latitude for location bias (optional)
  - lng: Longitude for location bias (optional)
  - radius: Bias radius in meters (optional)
  - limit: Total max results (optional, default: 10)
  
  ## Examples
  GET /api/places/autocomplete?input=123%20Main
  GET /api/places/autocomplete?input=Boston
  GET /api/places/autocomplete?input=Starbucks
  """
  def autocomplete(conn, params) do
    with {:ok, input} <- validate_required_string(params, "input"),
         {:ok, opts} <- build_hybrid_autocomplete_opts(params),
         {:ok, suggestions} <- AutocompleteService.search(input, opts) do
      cache_info = determine_cache_status(suggestions, :autocomplete)
      render(conn, :hybrid_autocomplete, suggestions: suggestions, cache_info: cache_info)
    end
  end

  @doc """
  Comprehensive autocomplete for addresses, cities, regions, and places.

  ## Parameters
  - input: Input text for autocomplete (required)
  - types: Comma-separated types to include (optional)
    - "address" - Street addresses
    - "city" - Cities and towns  
    - "region" - States, provinces, regions
    - "place" - Points of interest, businesses
    - "all" - All types (default)
  - lat: Latitude for location bias (optional)
  - lng: Longitude for location bias (optional) 
  - radius: Bias radius in meters (optional)
  - countries: ISO country codes for filtering (optional, default: "us,ca,mx")
  - limit: Max results per type (optional, default: 5)

  ## Examples
  GET /api/places/unified-autocomplete?input=San%20Francisco&types=city,address
  GET /api/places/unified-autocomplete?input=New%20York&types=all&lat=40.7128&lng=-74.0060
  """
  def unified_autocomplete(conn, params) do
    with {:ok, autocomplete_params} <- validate_unified_autocomplete_params(params),
         {:ok, suggestions} <- get_unified_autocomplete_suggestions(autocomplete_params) do
      cache_info = determine_autocomplete_cache_status(suggestions)
      render(conn, :unified_autocomplete, suggestions: suggestions, cache_info: cache_info)
    end
  end
  
  @doc """
  Legacy Google Places autocomplete (kept for backward compatibility).
  
  Use the main /autocomplete endpoint for comprehensive location search.
  """
  def legacy_autocomplete(conn, params) do
    with {:ok, autocomplete_params} <- validate_autocomplete_params(params),
         {:ok, suggestions} <- PlacesService.autocomplete_places(
           autocomplete_params.input,
           autocomplete_params.opts
         ) do
      # Autocomplete is always fresh from Google API (no caching)
      cache_info = {:cache_miss, :google_api}
      render(conn, :autocomplete, suggestions: suggestions, cache_info: cache_info)
    end
  end

  @doc """
  Find places by type near a location.

  ## Parameters
  - type: Place type (required)
  - lat: Latitude (required)
  - lng: Longitude (required)
  - radius: Search radius in meters (optional, default: 5000)

  ## Examples
  GET /api/places/nearby?type=restaurant&lat=37.7749&lng=-122.4194
  """
  def nearby(conn, params) do
    with {:ok, nearby_params} <- validate_nearby_params(params),
         {:ok, places} <- PlacesService.find_places_by_type(
           nearby_params.location,
           nearby_params.type,
           nearby_params.opts
         ) do
      cache_info = determine_cache_status(places, :nearby)
      render(conn, :nearby, places: places, cache_info: cache_info)
    end
  end

  @doc """
  Get photo URL for a place photo.

  ## Parameters
  - photo_reference: Google Places photo reference (required)
  - maxwidth: Maximum width in pixels (optional)
  - maxheight: Maximum height in pixels (optional)

  ## Examples
  GET /api/places/photo?photo_reference=...&maxwidth=400
  """
  def photo(conn, %{"photo_reference" => photo_reference} = params) do
    opts = build_photo_opts(params)
    photo_url = PlacesService.get_photo_url(photo_reference, opts)
    
    # Photo URLs are generated fresh each time (no caching)
    cache_info = {:cache_miss, :google_api}
    render(conn, :photo, photo_url: photo_url, cache_info: cache_info)
  end

  def photo(_conn, _params) do
    {:error, {:bad_request, "photo_reference is required"}}
  end

  @doc """
  City autocomplete endpoint using LocationIQ with intelligent database caching.

  Returns city suggestions based on search query with smart caching
  to reduce API calls and improve performance. Popular cities are
  cached in the database and returned instantly on subsequent searches.

  ## Parameters
  - q: Search query (required) - City name or partial name
  - limit: Max results, 1-20 (optional, default: 10)  
  - countries: Comma-separated country codes (optional, default: "us,ca,mx")

  ## Response Format
      {
        "status": "success",
        "data": {
          "cities": [
            {
              "id": "uuid",
              "name": "San Francisco", 
              "display_name": "San Francisco, California, United States",
              "lat": 37.7749,
              "lon": -122.4194,
              "country_code": "us"
            }
          ],
          "count": 1
        }
      }

  ## Examples
      GET /api/places/city-autocomplete?q=san%20francisco
      GET /api/places/city-autocomplete?q=new&limit=5&countries=us
  """
  def city_autocomplete(conn, %{"q" => query} = params) when byte_size(query) > 0 do
    limit = 
      case Map.get(params, "limit") do
        value when is_binary(value) ->
          case Integer.parse(value) do
            {int_val, ""} when int_val > 0 and int_val <= 20 -> int_val
            _ -> 10
          end
        _ -> 10
      end
    
    countries = Map.get(params, "countries", "us,ca,mx")
    
    opts = [limit: limit, countries: countries, min_results: 3]

    case Places.search_cities(query, opts) do
      {:ok, results} ->
        # City data comes from database cache  
        cache_info = {:cache_hit, :database}
        render(conn, :city_autocomplete, results: results, cache_info: cache_info)
      {:error, reason} ->
        {:error, {:bad_request, reason}}
    end
  end

  def city_autocomplete(_conn, _params) do
    {:error, {:bad_request, "q parameter is required and must be a non-empty string"}}
  end

  @doc """
  Get LocationIQ API monitoring dashboard.
  
  Returns comprehensive status, metrics, and health indicators
  for the LocationIQ protection systems.
  
  ## Examples
      GET /api/places/locationiq-status
  """
  def locationiq_status(conn, params) do
    user_id = Map.get(params, "user_id", "global")
    
    dashboard = RouteWiseApi.LocationIQ.Monitoring.get_dashboard(user_id)
    
    # Dashboard data is fresh each time (no caching)
    cache_info = {:cache_miss, :live_data}
    render(conn, :locationiq_status, dashboard: dashboard, cache_info: cache_info)
  end

  # Private validation functions

  defp validate_search_params(params) do
    with {:ok, query} <- validate_required_string(params, "query"),
         {:ok, location} <- validate_location(params),
         {:ok, opts} <- build_search_opts(params) do
      {:ok, %{query: query, location: location, opts: opts}}
    end
  end

  defp validate_autocomplete_params(params) do
    with {:ok, input} <- validate_required_string(params, "input"),
         {:ok, opts} <- build_autocomplete_opts(params) do
      {:ok, %{input: input, opts: opts}}
    end
  end

  defp validate_nearby_params(params) do
    with {:ok, type} <- validate_required_string(params, "type"),
         {:ok, location} <- validate_location(params),
         {:ok, opts} <- build_nearby_opts(params) do
      {:ok, %{type: type, location: location, opts: opts}}
    end
  end

  defp validate_required_string(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) and byte_size(value) > 0 ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "#{key} is required and must be a non-empty string"}}
    end
  end

  defp validate_location(params) do
    with {:ok, lat} <- validate_coordinate(params, "lat", -90, 90),
         {:ok, lng} <- validate_coordinate(params, "lng", -180, 180) do
      {:ok, %{lat: lat, lng: lng}}
    end
  end

  defp validate_coordinate(params, key, min, max) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case Float.parse(value) do
          {float_val, ""} when float_val >= min and float_val <= max ->
            {:ok, float_val}
          _ ->
            {:error, {:bad_request, "#{key} must be a valid number between #{min} and #{max}"}}
        end
      value when is_number(value) and value >= min and value <= max ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "#{key} is required and must be a valid number between #{min} and #{max}"}}
    end
  end

  defp build_search_opts(params) do
    opts = []
    
    opts = maybe_add_radius(opts, params)
    opts = maybe_add_type(opts, params)
    
    {:ok, opts}
  end

  defp build_autocomplete_opts(params) do
    opts = []
    
    opts = maybe_add_location_bias(opts, params)
    opts = maybe_add_radius(opts, params)
    opts = maybe_add_types(opts, params)
    
    {:ok, opts}
  end

  defp build_nearby_opts(params) do
    opts = []
    
    opts = maybe_add_radius(opts, params)
    
    {:ok, opts}
  end

  defp build_photo_opts(params) do
    []
    |> maybe_add_maxwidth(params)
    |> maybe_add_maxheight(params)
  end

  defp maybe_add_radius(opts, params) do
    case validate_positive_integer(params, "radius") do
      {:ok, radius} -> Keyword.put(opts, :radius, radius)
      _ -> opts
    end
  end

  defp maybe_add_type(opts, params) do
    case Map.get(params, "type") do
      type when is_binary(type) and byte_size(type) > 0 ->
        Keyword.put(opts, :type, type)
      _ ->
        opts
    end
  end

  defp maybe_add_types(opts, params) do
    case Map.get(params, "types") do
      types when is_binary(types) ->
        type_list = String.split(types, ",") |> Enum.map(&String.trim/1)
        Keyword.put(opts, :types, type_list)
      _ ->
        opts
    end
  end

  defp maybe_add_location_bias(opts, params) do
    case validate_location(params) do
      {:ok, location} -> Keyword.put(opts, :location, location)
      _ -> opts
    end
  end

  defp maybe_add_maxwidth(opts, params) do
    case validate_positive_integer(params, "maxwidth") do
      {:ok, maxwidth} -> Keyword.put(opts, :maxwidth, maxwidth)
      _ -> opts
    end
  end

  defp maybe_add_maxheight(opts, params) do
    case validate_positive_integer(params, "maxheight") do
      {:ok, maxheight} -> Keyword.put(opts, :maxheight, maxheight)
      _ -> opts
    end
  end

  defp validate_positive_integer(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_val, ""} when int_val > 0 ->
            {:ok, int_val}
          _ ->
            :error
        end
      value when is_integer(value) and value > 0 ->
        {:ok, value}
      _ ->
        :error
    end
  end

  # Cache status determination helper
  defp determine_cache_status(data, _operation_type) do
    import RouteWiseApiWeb.CacheHelpers
    
    cond do
      # If no data, can't determine cache status
      Enum.empty?(data) -> 
        :cache_disabled

      # For places operations (structs), check if cached_at timestamp is recent
      is_list(data) and is_struct(hd(data)) and hd(data).__struct__ == RouteWiseApi.Places.Place ->
        place = hd(data)
        cached_at = get_cached_at_timestamp(place)
        
        if cached_at do
          cache_age = DateTime.diff(DateTime.utc_now(), cached_at, :minute)
          
          if cache_age <= 60 do  # Less than 1 hour = likely cache hit
            {:cache_hit, get_current_backend()}
          else
            {:cache_miss, get_current_backend()}
          end
        else
          {:cache_miss, get_current_backend()}
        end

      # For API responses (plain maps), check if they have source field indicating cache hit
      is_list(data) and is_map(hd(data)) ->
        first_item = hd(data)
        case Map.get(first_item, :source) do
          "locationiq" -> {:cache_miss, "LocationIQ API"}
          "google_places" -> {:cache_miss, "Google Places API"} 
          _ -> {:cache_hit, get_current_backend()}
        end

      # Default: use backend status inference
      true ->
        infer_cache_status({:ok, data}, [])
    end
  end

  # Helper to check if data looks like place data (struct or map)
  defp is_place_data?(%{__struct__: RouteWiseApi.Places.Place}), do: true
  defp is_place_data?(%{"id" => _id}), do: true  # Map from cache
  defp is_place_data?(%{id: _id}), do: true      # Map with atom keys
  defp is_place_data?(_), do: false

  # Helper to safely get cached_at timestamp from struct or map
  defp get_cached_at_timestamp(%{__struct__: RouteWiseApi.Places.Place} = place) do
    place.cached_at || place.inserted_at
  end
  defp get_cached_at_timestamp(%{"cached_at" => cached_at}) when not is_nil(cached_at) do
    parse_datetime(cached_at)
  end
  defp get_cached_at_timestamp(%{cached_at: cached_at}) when not is_nil(cached_at) do
    parse_datetime(cached_at)
  end
  defp get_cached_at_timestamp(%{"inserted_at" => inserted_at}) when not is_nil(inserted_at) do
    parse_datetime(inserted_at)
  end
  defp get_cached_at_timestamp(%{inserted_at: inserted_at}) when not is_nil(inserted_at) do
    parse_datetime(inserted_at)
  end
  defp get_cached_at_timestamp(_), do: nil

  # Helper to parse datetime from string or return DateTime
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, dt, _} -> dt
      {:error, _} -> nil
    end
  end
  defp parse_datetime(_), do: nil

  # Smart autocomplete with pattern detection
  
  defp build_smart_autocomplete_opts(params) do
    opts = []
    
    # Add location bias if provided
    opts = maybe_add_location_bias(opts, params)
    
    # Add radius bias if provided
    opts = maybe_add_radius(opts, params)
    
    # Add total limit (distributed across sources)
    limit = case validate_positive_integer(params, "limit") do
      {:ok, limit_val} when limit_val <= 30 -> limit_val
      _ -> 10  # Default total limit
    end
    opts = Keyword.put(opts, :limit, limit)
    
    {:ok, opts}
  end

  # Helper function for hybrid autocomplete options
  defp build_hybrid_autocomplete_opts(params) do
    opts = %{}

    # Add limit
    opts = case validate_positive_integer(params, "limit") do
      {:ok, limit} when limit <= 50 -> Map.put(opts, :limit, limit)
      _ -> Map.put(opts, :limit, 10)
    end

    # Add country filter
    opts = case params["country"] do
      country when is_binary(country) and byte_size(country) == 2 ->
        Map.put(opts, :country, String.upcase(country))
      _ -> opts
    end

    # Add location for proximity scoring
    opts = case {validate_coordinate(params, "lat", -90, 90), validate_coordinate(params, "lon", -180, 180)} do
      {{:ok, lat}, {:ok, lon}} ->
        opts
        |> Map.put(:user_lat, lat)
        |> Map.put(:user_lon, lon)
      _ -> opts
    end

    # Add source preference
    opts = case params["source"] do
      "local" -> Map.put(opts, :source, :local)
      "locationiq" -> Map.put(opts, :source, :locationiq) 
      "google" -> Map.put(opts, :source, :google)
      _ -> Map.put(opts, :source, :auto)
    end

    {:ok, opts}
  end
  
  defp get_smart_autocomplete_suggestions(input, opts) do
    # Detect input patterns
    detected_types = detect_input_patterns(input)
    limit = Keyword.get(opts, :limit, 10)
    
    # Distribute limit across detected types
    per_type_limit = max(div(limit, length(detected_types)), 2)
    
    # Search each detected type
    results = Enum.reduce(detected_types, [], fn type, acc ->
      type_opts = Keyword.put(opts, :per_type_limit, per_type_limit)
      
      case get_suggestions_for_type(input, type, type_opts) do
        {:ok, suggestions} -> acc ++ suggestions
        {:error, _} -> acc  # Continue with other types on error
      end
    end)
    
    # Limit total results and add metadata
    final_suggestions = Enum.take(results, limit)
    
    response = %{
      suggestions: final_suggestions,
      count: length(final_suggestions),
      input: input,
      detected_types: detected_types
    }
    
    {:ok, response}
  end
  
  # Pattern detection logic
  
  defp detect_input_patterns(input) do
    input = String.trim(input)
    input_lower = String.downcase(input)
    word_count = input |> String.split() |> length()
    
    # Address pattern: starts with number (highest priority)
    if Regex.match?(~r/^\d+\s/, input) do
      ["address"]
    else
      # Business/place pattern: check for business keywords first
      business_keywords = ["starbucks", "mcdonald", "walmart", "target", "best buy", 
                          "home depot", "costco", "restaurant", "hotel", "gas station",
                          "pizza", "coffee", "bank", "pharmacy", "grocery", "mall"]
      has_business_keyword = Enum.any?(business_keywords, fn keyword ->
        String.contains?(input_lower, keyword)
      end)
      
      # Region pattern: state/country names
      region_indicators = ["california", "texas", "florida", "new york", "state", "province", 
                          "county", "country", "ca", "tx", "fl", "ny", "usa", "canada"]
      has_region_indicator = Enum.any?(region_indicators, fn region ->
        String.contains?(input_lower, region)
      end)
      
      # Priority order: specific patterns first, then fallbacks
      cond do
        # Clear business/place indicators
        has_business_keyword ->
          ["place"]
          
        # Clear region indicators  
        has_region_indicator ->
          ["region"]
          
        # Single word: likely a city
        word_count == 1 ->
          ["city"]
          
        # Two words: could be city with state, or business
        word_count == 2 ->
          ["city", "place"]
          
        # Longer phrases: likely places/businesses
        word_count > 2 ->
          ["place"]
          
        # Default fallback
        true ->
          ["city", "place"]
      end
    end
  end
  
  defp get_suggestions_for_type(input, "address", opts) do
    per_type_limit = Keyword.get(opts, :per_type_limit, 5)
    google_opts = build_google_places_opts(opts, ["address"])
    google_opts = Keyword.put(google_opts, :limit, per_type_limit)
    
    case PlacesService.autocomplete_places(input, google_opts) do
      {:ok, %{results: suggestions} = response} ->
        formatted = Enum.map(suggestions, fn suggestion ->
          suggestion
          |> Map.put("type", "address")
          |> Map.put("cache_status", Map.get(response, :cache_status, "unknown"))
        end)
        {:ok, formatted}
      {:ok, suggestions} when is_list(suggestions) ->
        # Fallback for backward compatibility
        formatted = Enum.map(suggestions, fn suggestion ->
          Map.put(suggestion, "type", "address")
        end)
        {:ok, formatted}
      error -> error
    end
  end
  
  defp get_suggestions_for_type(input, "city", opts) do
    per_type_limit = Keyword.get(opts, :per_type_limit, 5)
    
    # Use our city autocomplete with LocationIQ
    city_opts = [
      limit: per_type_limit,
      countries: "us,ca,mx",
      min_results: 1
    ]
    
    case Places.search_cities(input, city_opts) do
      {:ok, %{cities: cities}} ->
        # Convert to unified format
        formatted = Enum.map(cities, fn city ->
          %{
            "place_id" => city.id,
            "description" => city.display_name,
            "main_text" => city.name,
            "secondary_text" => String.replace(city.display_name, city.name <> ", ", ""),
            "location" => %{
              "lat" => city.lat,
              "lng" => city.lon
            },
            "type" => "city",
            "source" => "locationiq"
          }
        end)
        {:ok, formatted}
      error -> error
    end
  end
  
  defp get_suggestions_for_type(input, "place", opts) do
    per_type_limit = Keyword.get(opts, :per_type_limit, 5)
    google_opts = build_google_places_opts(opts, ["establishment", "point_of_interest"])
    google_opts = Keyword.put(google_opts, :limit, per_type_limit)
    
    case PlacesService.autocomplete_places(input, google_opts) do
      {:ok, %{results: suggestions} = response} ->
        formatted = Enum.map(suggestions, fn suggestion ->
          suggestion
          |> Map.put("type", "place")
          |> Map.put("cache_status", Map.get(response, :cache_status, "unknown"))
        end)
        {:ok, formatted}
      {:ok, suggestions} when is_list(suggestions) ->
        # Fallback for backward compatibility
        formatted = Enum.map(suggestions, fn suggestion ->
          Map.put(suggestion, "type", "place")
        end)
        {:ok, formatted}
      error -> error
    end
  end
  
  defp get_suggestions_for_type(input, "region", opts) do
    per_type_limit = Keyword.get(opts, :per_type_limit, 5)
    google_opts = build_google_places_opts(opts, ["administrative_area_level_1", "country"])
    google_opts = Keyword.put(google_opts, :limit, per_type_limit)
    
    case PlacesService.autocomplete_places(input, google_opts) do
      {:ok, %{results: suggestions} = response} ->
        formatted = Enum.map(suggestions, fn suggestion ->
          suggestion
          |> Map.put("type", "region")
          |> Map.put("cache_status", Map.get(response, :cache_status, "unknown"))
        end)
        {:ok, formatted}
      {:ok, suggestions} when is_list(suggestions) ->
        # Fallback for backward compatibility
        formatted = Enum.map(suggestions, fn suggestion ->
          Map.put(suggestion, "type", "region")
        end)
        {:ok, formatted}
      error -> error
    end
  end
  
  defp determine_smart_cache_status(response) do
    suggestions = Map.get(response, :suggestions, [])
    
    cond do
      Enum.empty?(suggestions) ->
        :cache_disabled
        
      # Check if any suggestions came from LocationIQ (cities)
      Enum.any?(suggestions, fn s -> Map.get(s, "source") == "locationiq" end) ->
        {:cache_hit, :database}
        
      # Otherwise, assume Google API (fresh)
      true ->
        {:cache_miss, :google_api}
    end
  end

  # Unified autocomplete validation and processing functions (kept for unified endpoint)
  
  defp validate_unified_autocomplete_params(params) do
    with {:ok, input} <- validate_required_string(params, "input"),
         {:ok, opts} <- build_unified_autocomplete_opts(params) do
      {:ok, %{input: input, opts: opts}}
    end
  end

  defp build_unified_autocomplete_opts(params) do
    opts = []
    
    # Parse types parameter - defaults to "all" if not specified
    types = case Map.get(params, "types") do
      nil -> ["all"]
      "" -> ["all"]
      type_string when is_binary(type_string) ->
        type_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(fn type -> type in ["address", "city", "region", "place", "all"] end)
        |> case do
          [] -> ["all"]  # Default to all if no valid types
          valid_types -> valid_types
        end
      _ -> ["all"]
    end
    
    opts = Keyword.put(opts, :types, types)
    
    # Add location bias if provided
    opts = maybe_add_location_bias(opts, params)
    
    # Add radius bias if provided
    opts = maybe_add_radius(opts, params)
    
    # Add countries filter
    countries = Map.get(params, "countries", "us,ca,mx")
    opts = Keyword.put(opts, :countries, countries)
    
    # Add limit per type
    limit = case validate_positive_integer(params, "limit") do
      {:ok, limit_val} when limit_val <= 20 -> limit_val
      _ -> 5  # Default limit
    end
    opts = Keyword.put(opts, :limit, limit)
    
    {:ok, opts}
  end

  defp get_unified_autocomplete_suggestions(%{input: input, opts: opts}) do
    types = Keyword.get(opts, :types, ["all"])
    limit = Keyword.get(opts, :limit, 5)
    
    # If "all" is in types, expand to all available types
    expanded_types = if "all" in types do
      ["address", "city", "region", "place"]
    else
      types
    end
    
    results = %{
      suggestions: %{},
      total_count: 0,
      input: input,
      types_requested: expanded_types
    }
    
    # Process each type and collect suggestions
    final_results = Enum.reduce(expanded_types, results, fn type, acc ->
      type_suggestions = case type do
        "address" -> get_address_suggestions(input, opts)
        "city" -> get_city_suggestions(input, opts)
        "region" -> get_region_suggestions(input, opts)
        "place" -> get_place_suggestions(input, opts)
        _ -> {:ok, []}
      end
      
      case type_suggestions do
        {:ok, suggestions} ->
          limited_suggestions = Enum.take(suggestions, limit)
          %{
            acc |
            suggestions: Map.put(acc.suggestions, type, limited_suggestions),
            total_count: acc.total_count + length(limited_suggestions)
          }
        {:error, _} ->
          # Log error but continue with other types
          %{
            acc |
            suggestions: Map.put(acc.suggestions, type, []),
            total_count: acc.total_count
          }
      end
    end)
    
    {:ok, final_results}
  end
  
  # Individual suggestion fetchers for each type
  
  defp get_address_suggestions(input, opts) do
    # Use Google Places API with address-specific types
    google_opts = build_google_places_opts(opts, ["address"])
    PlacesService.autocomplete_places(input, google_opts)
  end
  
  defp get_city_suggestions(input, opts) do
    # Use our city autocomplete with LocationIQ
    limit = Keyword.get(opts, :limit, 5)
    countries = Keyword.get(opts, :countries, "us,ca,mx")
    
    city_opts = [limit: limit, countries: countries, min_results: 1]
    
    case Places.search_cities(input, city_opts) do
      {:ok, %{cities: cities}} ->
        # Convert to unified format
        unified_cities = Enum.map(cities, fn city ->
          %{
            place_id: city.id,
            description: city.display_name,
            main_text: city.name,
            secondary_text: String.replace(city.display_name, city.name <> ", ", ""),
            types: ["locality", "political"],
            location: %{
              lat: city.lat,
              lng: city.lon
            },
            source: "locationiq"
          }
        end)
        {:ok, unified_cities}
      error -> error
    end
  end
  
  defp get_region_suggestions(input, opts) do
    # Use Google Places API with region-specific types
    google_opts = build_google_places_opts(opts, ["administrative_area_level_1", "country"])
    PlacesService.autocomplete_places(input, google_opts)
  end
  
  defp get_place_suggestions(input, opts) do
    # Use Google Places API with establishment types
    google_opts = build_google_places_opts(opts, ["establishment", "point_of_interest"])
    PlacesService.autocomplete_places(input, google_opts)
  end
  
  defp build_google_places_opts(opts, categories) do
    google_opts = []
    
    # Add types
    google_opts = Keyword.put(google_opts, :types, categories)
    
    # Add location bias if available
    case Keyword.get(opts, :location) do
      %{lat: lat, lng: lng} ->
        google_opts = Keyword.put(google_opts, :location, %{lat: lat, lng: lng})
        
        # Add radius if available
        case Keyword.get(opts, :radius) do
          radius when is_integer(radius) ->
            Keyword.put(google_opts, :radius, radius)
          _ ->
            google_opts
        end
      _ ->
        google_opts
    end
  end

  defp determine_autocomplete_cache_status(suggestions) do
    cond do
      is_nil(suggestions) or suggestions == %{} ->
        :cache_disabled
        
      # Check if any suggestions came from our database (cities)
      has_locationiq_suggestions?(suggestions) ->
        {:cache_hit, :database}
        
      # Otherwise, assume Google API (fresh)
      true ->
        {:cache_miss, :google_api}
    end
  end
  
  defp has_locationiq_suggestions?(%{suggestions: suggestion_map}) do
    case Map.get(suggestion_map, "city", []) do
      [] -> false
      cities -> Enum.any?(cities, fn city -> Map.get(city, :source) == "locationiq" end)
    end
  end
  
  defp has_locationiq_suggestions?(_), do: false

  defp get_current_backend do
    try do
      RouteWiseApi.Caching.backend()
    rescue
      _ -> :unknown
    end
  end
end