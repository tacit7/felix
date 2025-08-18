defmodule RouteWiseApi.Caching.Routes do
  @moduledoc """
  Route calculation caching for Google Directions API responses.

  Handles caching of route calculations with intelligent cache key generation
  based on origin, destination, and waypoints. Uses longer TTLs since
  routes don't change frequently.
  """

  alias RouteWiseApi.Caching.Config
  require Logger

  @doc """
  Get cached route calculation.

  ## Parameters

  - `origin` - Starting point (string or coordinates)
  - `destination` - End point (string or coordinates)
  - `waypoints` - Optional list of waypoints (default: [])

  ## Returns

  - `{:ok, route_data}` - Cached route found
  - `:error` - No cached route available
  """
  def get_cache(origin, destination, waypoints \\ []) do
    cache_key = build_route_key(origin, destination, waypoints)
    backend = Config.backend()

    Logger.debug("Routes cache hit: #{cache_key}")

    case backend.get(cache_key) do
      {:ok, data} ->
        if Config.debug_enabled?() do
          Logger.debug("Routes cache hit: #{cache_key}")
        end

        {:ok, data}

      :error ->
        if Config.debug_enabled?() do
          Logger.debug("Routes cache miss: #{cache_key}")
        end

        :error
    end
  end

  @doc """
  Cache route calculation results.

  Uses long TTL (1 hour) since routes rarely change for same parameters.

  ## Parameters

  - `origin` - Starting point
  - `destination` - End point
  - `waypoints` - List of waypoints (default: [])
  - `route_data` - Route calculation result to cache

  ## Returns

  - `:ok` - Successfully cached
  - `{:error, reason}` - Caching failed
  """
  def put_cache(origin, destination, waypoints \\ [], route_data) do
    cache_key = build_route_key(origin, destination, waypoints)
    # 1 hour for route calculations
    ttl = Config.ttl(:long)
    backend = Config.backend()

    case backend.put(cache_key, route_data, ttl) do
      :ok ->
        if Config.debug_enabled?() do
          Logger.debug("Routes cached: #{cache_key} (TTL: #{ttl}ms)")
        end

        :ok

      error ->
        Logger.warning("Failed to cache route #{cache_key}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Invalidate cached routes for specific origin/destination.

  Useful when route conditions change (road closures, etc.)
  """
  def invalidate_route_cache(origin, destination, waypoints \\ []) do
    cache_key = build_route_key(origin, destination, waypoints)
    backend = Config.backend()

    backend.delete(cache_key)
  end

  # Private functions

  defp build_route_key(origin, destination, waypoints) do
    # Sort waypoints for consistent cache keys regardless of order
    sorted_waypoints = Enum.sort(waypoints)

    # Combine all route components
    route_components = [origin, destination | sorted_waypoints]
    route_string = Enum.join(route_components, "|")

    # Create hash for consistent, manageable key length
    route_hash = :crypto.hash(:md5, route_string) |> Base.encode16()

    "routes:calculation:#{route_hash}"
  end
end
