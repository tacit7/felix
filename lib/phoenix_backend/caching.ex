defmodule RouteWiseApi.Caching do
  @moduledoc """
  Centralized caching context for the RouteWise API.

  This context provides high-level caching functions that adapt to different
  environments and delegate to appropriate cache backends and domain modules.
  """

  alias RouteWiseApi.Caching.{Config, Dashboard, Places, Routes, Trips, Interests, Statistics}
  require Logger

  @doc """
  Get the current cache backend module.
  """
  def backend, do: Config.backend()

  @doc """
  Generic cache get operation.
  """
  def get(key) do
    backend_module = backend()
    backend_module.get(key)
  end

  @doc """
  Generic cache put operation with TTL.
  """
  def put(key, value, opts \\ []) do
    backend_module = backend()
    ttl_ms = Keyword.get(opts, :ttl, 3600) * 1000 # Convert seconds to milliseconds
    backend_module.put(key, value, ttl_ms)
  end

  @doc """
  Dashboard caching operations.
  """
  defdelegate get_dashboard_cache(user_id), to: Dashboard, as: :get_cache
  defdelegate put_dashboard_cache(user_id, data), to: Dashboard, as: :put_cache
  defdelegate invalidate_dashboard_cache(user_id), to: Dashboard, as: :invalidate_cache

  @doc """
  Places caching operations.
  """
  defdelegate get_places_search_cache(query, location), to: Places, as: :get_search_cache
  defdelegate put_places_search_cache(query, location, results), to: Places, as: :put_search_cache
  defdelegate get_place_details_cache(place_id), to: Places, as: :get_details_cache
  defdelegate put_place_details_cache(place_id, details), to: Places, as: :put_details_cache

  @doc """
  Routes caching operations.
  """
  defdelegate get_route_cache(origin, destination, waypoints), to: Routes, as: :get_cache

  defdelegate put_route_cache(origin, destination, waypoints, route_data),
    to: Routes,
    as: :put_cache

  @doc """
  Trips caching operations.
  """
  defdelegate get_public_trips_cache(), to: Trips, as: :get_public_cache
  defdelegate put_public_trips_cache(trips), to: Trips, as: :put_public_cache
  defdelegate get_user_trips_cache(user_id), to: Trips, as: :get_user_cache
  defdelegate put_user_trips_cache(user_id, trips), to: Trips, as: :put_user_cache
  defdelegate invalidate_user_trips_cache(user_id), to: Trips, as: :invalidate_user_cache

  @doc """
  Interests caching operations.
  """
  defdelegate get_interest_categories_cache(), to: Interests, as: :get_categories_cache
  defdelegate put_interest_categories_cache(categories), to: Interests, as: :put_categories_cache

  @doc """
  Statistics caching operations.
  """
  defdelegate get_statistics_cache(), to: Statistics, as: :get_cache
  defdelegate put_statistics_cache(stats), to: Statistics, as: :put_cache

  @doc """
  Get comprehensive cache statistics for monitoring.
  """
  def get_cache_statistics do
    backend_module = backend()
    backend_stats = backend_module.stats()

    %{
      backend_stats: backend_stats,
      ttl_policies: get_ttl_policies(),
      cache_categories: Config.invalidation_config()[:cache_categories] || [],
      environment: Mix.env(),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Clear all cache entries across all categories and backends.
  """
  def clear_all_cache do
    backend_module = backend()

    case backend_module.clear() do
      :ok ->
        Logger.info("All cache cleared via #{inspect(backend_module)}")
        :ok

      error ->
        Logger.error("Failed to clear cache: #{inspect(error)}")
        error
    end
  end

  @doc """
  Invalidate all user-specific caches for a given user.
  Useful when user data changes (profile updates, preferences, etc.)
  """
  def invalidate_user_cache(user_id) do
    Dashboard.invalidate_cache(user_id)
    Trips.invalidate_user_cache(user_id)

    Logger.info("Invalidated all user caches for user #{user_id}")
    :ok
  end

  @doc """
  Perform a health check on the caching system.
  """
  def health_check do
    backend_module = backend()

    case backend_module.health_check() do
      :ok ->
        {:ok,
         %{
           status: :healthy,
           backend: backend_module,
           timestamp: DateTime.utc_now()
         }}

      {:error, reason} ->
        Logger.warning("Cache health check failed: #{inspect(reason)}")

        {:error,
         %{
           status: :unhealthy,
           backend: backend_module,
           reason: reason,
           timestamp: DateTime.utc_now()
         }}
    end
  end

  @doc """
  Get cache utilization metrics for monitoring and alerting.
  """
  def get_cache_utilization do
    backend_module = backend()
    stats = backend_module.stats()

    %{
      backend: backend_module,
      total_keys: Map.get(stats, :total_keys, 0),
      memory_usage: :erlang.memory(:total),
      hit_ratio: calculate_hit_ratio(stats),
      health_status: Map.get(stats, :health_status, :unknown),
      environment: Mix.env(),
      timestamp: DateTime.utc_now()
    }
  end

  # Private helper functions

  defp get_ttl_policies do
    %{
      short: "#{Config.ttl(:short)}ms (#{Config.ttl_seconds(:short)}s)",
      medium: "#{Config.ttl(:medium)}ms (#{Config.ttl_seconds(:medium)}s)",
      long: "#{Config.ttl(:long)}ms (#{Config.ttl_seconds(:long)}s)",
      daily: "#{Config.ttl(:daily)}ms (#{Config.ttl_seconds(:daily)}s)"
    }
  end

  defp calculate_hit_ratio(stats) do
    # This would need to be implemented with proper hit/miss counters
    # For now, return a placeholder based on available stats
    case Map.get(stats, :hit_tracking) do
      nil -> 0.0
      tracking when is_map(tracking) and map_size(tracking) > 0 -> 0.85
      _ -> 0.0
    end
  end
end
