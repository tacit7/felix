defmodule RouteWiseApi.PlacesService do
  @moduledoc """
  Service for managing places with intelligent caching and LocationIQ API integration.
  """

  alias RouteWiseApi.{Places, LocationIQ}
  alias RouteWiseApi.Places.Place

  require Logger

  @cache_ttl_hours 24
  @default_search_radius 5000

  @doc """
  Search for places with intelligent caching.

  First checks local cache, then falls back to Google Places API if needed.
  Caches results locally for faster subsequent requests.

  ## Examples

      iex> search_places("restaurants", %{lat: 37.7749, lng: -122.4194})
      {:ok, [%Place{}, ...]}

  """
  def search_places(query, location, opts \\ []) do
    radius = opts[:radius] || @default_search_radius

    # Database-only search - no API calls
    cached_places = Places.search_places_near(location, query, radius)

    if Enum.any?(cached_places) do
      Logger.info("🎯 Database-only POI search found #{length(cached_places)} places for query: #{query}")
      {:ok, cached_places}
    else
      Logger.info("🔍 No database POI results found for query: #{query} at location: #{inspect(location)}")
      {:ok, []}  # Return empty list instead of error
    end
  end

  @doc """
  Get detailed place information by LocationIQ Place ID.

  Checks cache first, then fetches from LocationIQ API if needed or cache is stale.

  ## Examples

      iex> get_place_details("12345")
      {:ok, %Place{}}

  """
  def get_place_details(location_iq_place_id, opts \\ []) do
    case Places.get_place_by_location_iq_id(location_iq_place_id) do
      %Place{} = place ->
        if Place.cache_fresh?(place, @cache_ttl_hours) do
          Logger.debug("Returning cached place details for: #{location_iq_place_id}")
          {:ok, place}
        else
          Logger.debug("Refreshing stale place details for: #{location_iq_place_id}")
          refresh_place_details(place, opts)
        end

      nil ->
        Logger.debug("Fetching new place details for: #{location_iq_place_id}")
        fetch_and_cache_place_details(location_iq_place_id, opts)
    end
  end

  @doc """
  Get autocomplete suggestions for place search with aggressive caching.

  Caches results with long TTL since autocomplete data is essentially static:
  - Addresses/Regions: 1 week (locations don't change)
  - Businesses: 1 week (business names/locations don't change frequently)
  - Mixed/Unknown: 1 day (fallback for unrecognized result types)

  ## Examples

      iex> autocomplete_places("San Franc")
      {:ok, [%{description: "San Francisco, CA, USA", place_id: "..."}, ...]}

  """
  def autocomplete_places(input, opts \\ []) do
    cache_key = generate_autocomplete_cache_key(input, opts)
    
    case RouteWiseApi.Caching.get(cache_key) do
      {:ok, cached_data} ->
        Logger.debug("Returning cached autocomplete for: #{input}")
        {:ok, Map.put(cached_data, :cache_status, "hit")}
        
      :error ->
        Logger.debug("Fetching fresh autocomplete from LocationIQ for: #{input}")
        
        case LocationIQ.autocomplete_cities(input, opts) do
          {:ok, results} ->
            formatted_predictions = Enum.map(results, &format_location_iq_prediction/1)
            response_data = %{results: formatted_predictions, cache_status: "miss"}
            
            # Cache with TTL based on result types
            ttl = determine_autocomplete_cache_ttl(formatted_predictions)
            RouteWiseApi.Caching.put(cache_key, response_data, ttl: ttl)
            
            {:ok, response_data}

          {:error, reason} ->
            # Return empty results for errors to avoid repeated API calls
            empty_response = %{results: [], cache_status: "miss"}
            RouteWiseApi.Caching.put(cache_key, empty_response, ttl: 900) # 15 minutes
            Logger.error("LocationIQ autocomplete request failed: #{inspect(reason)}")
            {:ok, empty_response}
        end
    end
  end

  @doc """
  Find places by type near a location.

  ## Examples

      iex> find_places_by_type(%{lat: 37.7749, lng: -122.4194}, "restaurant")
      {:ok, [%Place{}, ...]}

  """
  def find_places_by_type(location, place_type, opts \\ []) do
    radius = opts[:radius] || @default_search_radius

    # Check cache first
    cached_places = Places.get_places_by_type(location, place_type, radius)

    if Enum.any?(cached_places) and all_cache_fresh?(cached_places) do
      Logger.debug("Returning cached places by type: #{place_type}")
      {:ok, cached_places}
    else
      Logger.debug("Fetching fresh places by type from Google Places API: #{place_type}")
      fetch_and_cache_places_by_type(location, place_type, opts)
    end
  end

  @doc """
  Get photo URL for a place photo reference.
  
  Note: LocationIQ doesn't provide photo URLs like Google Places.
  This function now returns nil or a placeholder.

  ## Examples

      iex> get_photo_url("photo_reference_string", maxwidth: 400)
      nil

  """
  def get_photo_url(_photo_reference, _opts \\ []) do
    # LocationIQ doesn't provide place photos like Google Places
    # You might want to integrate with a different photo service
    # or return a placeholder image URL
    nil
  end

  @doc """
  Clean up old cached place data.

  ## Examples

      iex> cleanup_old_cache()
      :ok

  """
  def cleanup_old_cache(hours \\ 48) do
    case Places.cleanup_old_cache(hours: hours) do
      {count, _} when count > 0 ->
        Logger.info("Cleaned up #{count} old cached places")
        :ok

      {0, _} ->
        Logger.debug("No old cached places to clean up")
        :ok
    end
  end

  # Private functions

  defp fetch_and_cache_places(query, location, opts) do
    location_iq_opts = build_location_iq_search_opts(location, opts)

    case LocationIQ.search_places(query, location, location_iq_opts) do
      {:ok, results} ->
        places = cache_location_iq_results(results)
        {:ok, places}

      {:error, reason} ->
        Logger.error("LocationIQ places search failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_and_cache_places_by_type(location, place_type, opts) do
    location_iq_opts = build_location_iq_search_opts(location, opts)
    
    # LocationIQ uses category search, map common place types
    query = map_place_type_to_query(place_type)

    case LocationIQ.search_places(query, location, location_iq_opts) do
      {:ok, results} ->
        places = cache_location_iq_results(results)
        {:ok, places}

      {:error, reason} ->
        Logger.error("LocationIQ places by type search failed: #{inspect(reason)}")
        {:error, reason}
        
      # Handle circuit breaker fallback pattern
      {:error, _api_error, fallback_result} ->
        Logger.warning("Circuit breaker fallback for places search: #{inspect(fallback_result)}")
        case fallback_result do
          {:ok, results} ->
            places = cache_location_iq_results(results)
            {:ok, places}
          _ ->
            {:ok, []}  # Return empty list on fallback failure
        end
    end
  end

  defp fetch_and_cache_place_details(location_iq_place_id, opts) do
    case LocationIQ.get_place_details(location_iq_place_id, opts) do
      {:ok, result} ->
        case Places.create_place_from_location_iq(result) do
          {:ok, place} ->
            {:ok, place}

          {:error, changeset} ->
            Logger.error("Failed to cache place details: #{inspect(changeset.errors)}")
            {:error, :cache_failed}
        end

      {:error, reason} ->
        Logger.error("LocationIQ place details request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp refresh_place_details(%Place{location_iq_place_id: location_iq_place_id} = place, opts) do
    case fetch_and_cache_place_details(location_iq_place_id, opts) do
      {:ok, updated_place} ->
        {:ok, updated_place}

      {:error, _reason} ->
        # If refresh fails, return stale cached data
        Logger.warning("Failed to refresh place details, returning stale cache for: #{location_iq_place_id}")
        {:ok, place}
    end
  end

  defp cache_location_iq_results(results) do
    results
    |> Enum.map(&cache_single_result/1)
    |> Enum.filter(& &1)
  end

  defp cache_single_result(location_iq_result) do
    case Places.upsert_place_from_location_iq(location_iq_result) do
      {:ok, place} ->
        place_name = location_iq_result[:name] || location_iq_result["name"] || "Unknown Place"
        description = location_iq_result[:description] || location_iq_result["description"] || "No description"
        
        Logger.info("🔍 Enhanced POI #{place_name}: #{String.slice(description, 0, 80)}#{if String.length(description) > 80, do: "...", else: ""}")
        place

      {:error, changeset} ->
        Logger.error("Failed to cache place: #{inspect(changeset.errors)}")
        nil
    end
  end

  defp all_cache_fresh?(places) do
    Enum.all?(places, &Place.cache_fresh?(&1, @cache_ttl_hours))
  end

  defp build_location_iq_search_opts(location, opts) do
    opts
    |> Keyword.put_new(:limit, 15)
    |> Keyword.put_new(:radius, @default_search_radius)
  end

  defp map_place_type_to_query(place_type) do
    case place_type do
      "restaurant" -> "restaurant"
      "gas_station" -> "gas station"
      "lodging" -> "hotel"
      "tourist_attraction" -> "attraction"
      "shopping_mall" -> "mall"
      "bank" -> "bank"
      "atm" -> "atm"
      "hospital" -> "hospital"
      "pharmacy" -> "pharmacy"
      _ -> place_type
    end
  end

  defp format_location_iq_prediction(prediction) do
    %{
      place_id: prediction[:place_id] || prediction["place_id"],
      description: prediction[:display_name] || prediction["display_name"],
      city: prediction[:city] || prediction["city"],
      state: prediction[:state] || prediction["state"],
      country: prediction[:country] || prediction["country"],
      types: ["locality"] # LocationIQ autocomplete is primarily for cities
    }
  end

  # Cache helper functions for autocomplete
  
  defp generate_autocomplete_cache_key(input, opts) do
    # Include relevant options in cache key
    key_opts = opts
    |> Keyword.take([:types, :components, :location, :radius])
    |> Enum.sort()
    
    "autocomplete:#{String.downcase(input)}:#{:crypto.hash(:md5, inspect(key_opts)) |> Base.encode16()}"
  end
  
  defp determine_autocomplete_cache_ttl(results) do
    cond do
      has_address_or_region_results?(results) ->
        604800 # 1 week for addresses/regions (static data)
        
      has_business_results?(results) ->
        604800 # 1 week for businesses (names/locations don't change)
        
      true ->
        86400 # 1 day for mixed/unknown types
    end
  end
  
  defp has_business_results?(results) do
    Enum.any?(results, fn result ->
      types = result.types || []
      Enum.any?(types, &(&1 in ["establishment", "point_of_interest", "store", "restaurant", "lodging"]))
    end)
  end
  
  defp has_address_or_region_results?(results) do
    Enum.any?(results, fn result ->
      types = result.types || []
      Enum.any?(types, &(&1 in ["street_address", "route", "locality", "administrative_area_level_1", "administrative_area_level_2", "country"]))
    end)
  end
end