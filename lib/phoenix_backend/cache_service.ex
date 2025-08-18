defmodule RouteWiseApi.CacheService do
  @moduledoc """
  Service for handling cache operations and metadata for explore results.
  
  Provides:
  - Cache status determination for POI data
  - Geocoding cache management
  - Cache backend utilities
  """
  
  require Logger

  @doc """
  Determine cache status for explore results based on POI data freshness.
  """
  def determine_explore_results_cache_status(pois) do
    cond do
      # No data - cache disabled
      Enum.empty?(pois) ->
        :cache_disabled

      # POI data exists - analyze freshness
      not Enum.empty?(pois) ->
        poi = hd(pois)
        case Map.get(poi, :updated_at) || Map.get(poi, :inserted_at) do
          nil -> {:cache_miss, :google_places}
          timestamp ->
            # Check if data is fresh (within last hour)
            case DateTime.from_naive(timestamp, "Etc/UTC") do
              {:ok, poi_datetime} ->
                age_minutes = DateTime.diff(DateTime.utc_now(), poi_datetime, :minute)
                if age_minutes <= 60 do
                  {:cache_hit, get_current_backend()}
                else
                  {:cache_miss, :google_places}
                end
              _ ->
                {:cache_miss, :google_places}
            end
        end

      # Default case
      true ->
        {:cache_miss, :mixed}
    end
  end

  @doc """
  Get current cache backend for metadata.
  """
  def get_current_backend do
    try do
      RouteWiseApi.Caching.backend()
    rescue
      _ -> :memory
    end
  end

  @doc """
  Get cache backend instance for operations.
  """
  def get_cache_backend do
    try do
      RouteWiseApi.Caching.backend()
    rescue
      _ -> RouteWiseApi.Caching.Backend.Memory
    end
  end

  @doc """
  Cache geocoding results with bounds calculation.
  """
  def geocode_city_with_bounds_cache(location_name, fetch_fn) do
    cache_key = "geocode_bounds:#{String.downcase(location_name)}"
    backend = get_cache_backend()
    
    case backend.get(cache_key) do
      {:ok, cached_data} ->
        Logger.debug("📍 Cache hit for geocoding with bounds: #{location_name}")
        cached_data
      :error ->
        Logger.debug("📍 Cache miss for geocoding with bounds: #{location_name}, calculating...")
        location_data = fetch_fn.()
        
        # Cache for 30 days (locations are stable)
        if location_data do
          backend.put(cache_key, location_data, :timer.hours(24 * 30))
        end
        
        location_data
    end
  end
end