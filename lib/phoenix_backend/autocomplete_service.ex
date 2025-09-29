defmodule RouteWiseApi.AutocompleteService do
  @moduledoc """
  Hybrid autocomplete service with intelligent three-tier fallback:
  
  1. Local Cache (cached_places) - instant results for popular places
  2. LocationIQ API - comprehensive global coverage  
  3. Google Places API - fallback for specific addresses
  
  Provides fast, cost-effective autocomplete with intelligent result merging.
  """

  require Logger
  alias RouteWiseApi.Places
  alias RouteWiseApi.LocationIQAutocomplete
  alias RouteWiseApi.GooglePlaces
  alias RouteWiseApi.Caching

  @default_limit 10
  @cache_ttl 300  # 5 minutes for autocomplete results
  @min_query_length 2

  @doc """
  Main autocomplete function with intelligent three-tier fallback.
  
  ## Parameters
  - query: Search term (minimum 2 characters)
  - opts: Options map
    - limit: Maximum results (default: 10)
    - country: 2-letter country code filter
    - user_lat: User latitude for proximity scoring
    - user_lon: User longitude for proximity scoring
    - source: Force specific source (:local, :locationiq, :google, :auto)
  
  ## Returns
  {:ok, [%{id: "...", name: "...", lat: 12.34, lon: 56.78, type: 3, source: "local"}]} | {:error, reason}
  """
  def search(query, opts \\ %{}) do
    with :ok <- validate_query(query),
         {:ok, cache_key} <- build_cache_key(query, opts),
         {:ok, results} <- get_or_fetch_results(cache_key, query, opts) do
      
      # Track usage for cached places to improve future ranking
      track_result_usage(results)
      
      {:ok, limit_results(results, Map.get(opts, :limit, @default_limit))}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Search with specific source (bypass intelligent fallback).
  """
  def search_with_source(query, source, opts \\ %{}) do
    case source do
      :local -> search_local_only(query, opts)
      :locationiq -> search_locationiq_only(query, opts)
      :google -> search_google_only(query, opts)
      _ -> {:error, "Invalid source. Use :local, :locationiq, or :google"}
    end
  end

  # Private functions

  defp validate_query(query) when is_binary(query) do
    trimmed = String.trim(query)
    if String.length(trimmed) >= @min_query_length do
      :ok
    else
      {:error, "Query must be at least #{@min_query_length} characters"}
    end
  end
  defp validate_query(_), do: {:error, "Query must be a string"}

  defp build_cache_key(query, opts) do
    normalized_query = String.downcase(String.trim(query))
    country = Map.get(opts, :country, "")
    limit = Map.get(opts, :limit, @default_limit)
    
    key = "autocomplete:#{normalized_query}:#{country}:#{limit}"
    {:ok, key}
  end

  defp get_or_fetch_results(cache_key, query, opts) do
    # Create a simple location string for caching
    location = if opts[:user_lat] && opts[:user_lon] do
      "#{opts[:user_lat]},#{opts[:user_lon]}"
    else
      "global"
    end
    
    case Caching.get_places_search_cache(query, location) do
      {:ok, cached_results} ->
        Logger.debug("Autocomplete cache hit for: #{query}")
        {:ok, cached_results}
      
      :error ->
        Logger.debug("Autocomplete cache miss for: #{query}")
        fetch_and_cache_results(query, location, opts)
    end
  end

  defp fetch_and_cache_results(query, location, opts) do
    source = Map.get(opts, :source, :auto)
    
    results = case source do
      :auto -> search_with_intelligent_fallback(query, opts)
      :local -> search_local_only(query, opts)
      :locationiq -> search_locationiq_only(query, opts)
      :google -> search_google_only(query, opts)
    end

    case results do
      {:ok, data} when is_list(data) ->
        # Cache successful results
        Caching.put_places_search_cache(query, location, data)
        {:ok, data}
      {:error, reason} = error ->
        Logger.warning("Autocomplete fetch failed: #{reason}")
        error
    end
  end

  defp search_with_intelligent_fallback(query, opts) do
    # Step 1: Search local cache first
    local_results = case search_local_only(query, opts) do
      {:ok, results} -> results
      {:error, _} -> []
    end

    target_limit = Map.get(opts, :limit, @default_limit)
    
    if length(local_results) >= target_limit do
      # Sufficient local results
      {:ok, local_results}
    else
      # Step 2: Supplement with LocationIQ
      remaining_limit = target_limit - length(local_results)
      locationiq_opts = Map.put(opts, :limit, remaining_limit * 2)  # Get extra for deduplication
      
      locationiq_results = case search_locationiq_only(query, locationiq_opts) do
        {:ok, results} -> results
        {:error, reason} -> 
          Logger.warning("LocationIQ autocomplete failed: #{reason}")
          []
      end

      combined_results = deduplicate_results(local_results ++ locationiq_results)
      
      if length(combined_results) >= target_limit do
        {:ok, combined_results}
      else
        # Step 3: Final fallback to Google Places
        remaining_limit = target_limit - length(combined_results)
        google_opts = Map.put(opts, :limit, remaining_limit)
        
        google_results = case search_google_only(query, google_opts) do
          {:ok, results} -> results
          {:error, reason} ->
            Logger.warning("Google Places autocomplete failed: #{reason}")
            []
        end

        final_results = deduplicate_results(combined_results ++ google_results)
        {:ok, final_results}
      end
    end
  end

  defp search_local_only(query, opts) do
    limit = Map.get(opts, :limit, @default_limit)
    country = Map.get(opts, :country)
    
    results = Places.search_cached_places(query, limit)
    
    filtered_results = if country do
      Enum.filter(results, &(&1.country_code == String.upcase(country)))
    else
      results
    end

    formatted_results = Enum.map(filtered_results, &format_cached_result/1)
    {:ok, formatted_results}
  end

  defp search_locationiq_only(query, opts) do
    locationiq_opts = build_locationiq_options(opts)
    
    case LocationIQAutocomplete.search(query, locationiq_opts) do
      {:ok, results} ->
        formatted_results = Enum.map(results, &format_locationiq_result/1)
        {:ok, formatted_results}
      
      {:error, reason} ->
        {:error, "LocationIQ search failed: #{reason}"}
    end
  end

  defp search_google_only(query, opts) do
    # Convert map opts to keyword list for GooglePlaces
    google_opts = if is_map(opts) do
      Enum.to_list(opts)
    else
      opts
    end

    # Use existing Google Places autocomplete
    case GooglePlaces.autocomplete(query, google_opts) do
      {:ok, %{"predictions" => predictions}} when is_list(predictions) ->
        formatted_results = Enum.map(predictions, &format_google_result/1)
        {:ok, formatted_results}
      
      {:ok, %{"status" => "ZERO_RESULTS"}} ->
        {:ok, []}
        
      {:ok, response} ->
        Logger.warning("Unexpected Google Places response format: #{inspect(response)}")
        {:ok, []}
      
      {:error, reason} ->
        {:error, "Google Places search failed: #{reason}"}
    end
  end

  defp build_locationiq_options(opts) do
    locationiq_opts = %{}
    
    locationiq_opts
    |> maybe_add_country_filter(opts)
    |> maybe_add_limit(opts)
    |> maybe_add_viewbox(opts)
  end

  defp maybe_add_country_filter(locationiq_opts, %{country: country}) when is_binary(country) do
    Map.put(locationiq_opts, :country_codes, [String.downcase(country)])
  end
  defp maybe_add_country_filter(locationiq_opts, _), do: locationiq_opts

  defp maybe_add_limit(locationiq_opts, %{limit: limit}) when is_integer(limit) do
    Map.put(locationiq_opts, :limit, limit)
  end
  defp maybe_add_limit(locationiq_opts, _), do: locationiq_opts

  defp maybe_add_viewbox(locationiq_opts, %{user_lat: lat, user_lon: lon}) 
    when is_number(lat) and is_number(lon) do
    # Create viewbox around user location (roughly 50km radius)
    delta = 0.5
    viewbox = "#{lon - delta},#{lat + delta},#{lon + delta},#{lat - delta}"
    Map.put(locationiq_opts, :viewbox, viewbox)
  end
  defp maybe_add_viewbox(locationiq_opts, _), do: locationiq_opts

  defp deduplicate_results(results) do
    results
    |> Enum.uniq_by(fn result ->
      # Improved deduplication:
      # 1. For LocationIQ results with same ID and name, keep only the first one
      # 2. For other sources, dedupe by name + approximate location
      name_key = String.downcase(result.name)

      if result.source == "locationiq" do
        # For LocationIQ, use ID + name to dedupe exact duplicates
        {result.id, name_key}
      else
        # For other sources, use name + location
        lat_key = if result.lat, do: Float.round(result.lat, 2), else: nil
        lon_key = if result.lon, do: Float.round(result.lon, 2), else: nil
        {name_key, lat_key, lon_key}
      end
    end)
    |> Enum.sort_by(&result_sort_priority/1)
  end

  defp result_sort_priority(result) do
    # Sort by: source priority, place type, name
    source_priority = case result.source do
      "local" -> 0      # Highest priority
      "locationiq" -> 1
      "google" -> 2     # Lowest priority
      _ -> 3
    end
    
    {source_priority, result.type, result.name}
  end

  defp format_cached_result(cached_place) do
    # Create a display name based on location hierarchy
    display_name = build_display_name(
      cached_place.name,
      cached_place.admin1_code,
      cached_place.country_code,
      cached_place.place_type
    )
    
    %{
      id: cached_place.id,
      name: cached_place.name,
      display_name: display_name,
      lat: cached_place.lat,
      lon: cached_place.lon,
      type: cached_place.place_type,
      country_code: cached_place.country_code,
      admin1_code: cached_place.admin1_code,
      source: "local",
      popularity_score: cached_place.popularity_score
    }
  end

  defp format_locationiq_result(locationiq_result) do
    %{
      id: locationiq_result.id,
      name: locationiq_result.name,
      display_name: locationiq_result.display_name,
      lat: locationiq_result.lat,
      lon: locationiq_result.lon,
      type: locationiq_result.type,
      country_code: locationiq_result.country_code,
      address: locationiq_result.address,
      source: "locationiq"
    }
  end

  defp format_google_result(google_result) do
    name = google_result["structured_formatting"]["main_text"] || google_result["description"] || google_result["name"]
    display_name = google_result["description"] || name
    
    %{
      id: google_result["place_id"],
      name: name,
      display_name: display_name,
      lat: nil,  # Google autocomplete doesn't include coordinates
      lon: nil,
      type: classify_google_place_type(google_result),
      source: "google",
      place_id: google_result["place_id"]
    }
  end

  defp classify_google_place_type(google_result) do
    types = google_result["types"] || []
    
    cond do
      "country" in types -> 1
      "administrative_area_level_1" in types -> 2
      "locality" in types or "sublocality" in types -> 3
      true -> 5  # POI
    end
  end

  defp track_result_usage(results) do
    # Track usage for local cache results to improve future ranking
    Task.start(fn ->
      for result <- results, result.source == "local" do
        case Places.get_cached_place_by_name_and_type(result.name, result.type) do
          nil -> :ok  # Place not found in cache
          cached_place -> Places.increment_cached_place_usage(cached_place)
        end
      end
    end)
  end

  defp limit_results(results, limit) do
    Enum.take(results, limit)
  end

  defp build_display_name(name, admin1_code, country_code, place_type) do
    # Build a hierarchical display name for better UX
    components = [name]
    
    # Add admin1 (state/province) for cities and POIs
    components = if admin1_code && place_type in [3, 5] do
      # Convert "US-CA" to "California", "US-NY" to "New York", etc.
      admin1_name = case admin1_code do
        "US-" <> state_code -> get_us_state_name(state_code)
        other -> other
      end
      components ++ [admin1_name]
    else
      components
    end
    
    # Add country for international results or when helpful
    components = if country_code && country_code != "US" do
      country_name = get_country_name(country_code)
      components ++ [country_name]
    else
      components
    end
    
    Enum.join(components, ", ")
  end

  defp get_us_state_name(state_code) do
    case state_code do
      "AZ" -> "Arizona"
      "CA" -> "California"
      "FL" -> "Florida"
      "NY" -> "New York"
      "TX" -> "Texas"
      "WY" -> "Wyoming"
      "NV" -> "Nevada"
      "UT" -> "Utah"
      "CO" -> "Colorado"
      "WA" -> "Washington"
      "OR" -> "Oregon"
      "MT" -> "Montana"
      "ID" -> "Idaho"
      "NM" -> "New Mexico"
      other -> other  # Fallback to abbreviation
    end
  end

  defp get_country_name(country_code) do
    case String.upcase(country_code) do
      "US" -> "United States"
      "CA" -> "Canada"
      "MX" -> "Mexico"
      "GB" -> "United Kingdom"
      "FR" -> "France"
      "DE" -> "Germany"
      "ES" -> "Spain"
      "IT" -> "Italy"
      "JP" -> "Japan"
      other -> other  # Fallback to country code
    end
  end
end