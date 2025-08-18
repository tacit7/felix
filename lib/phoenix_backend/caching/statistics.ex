defmodule RouteWiseApi.Caching.Statistics do
  @moduledoc """
  Application statistics caching module.

  Provides caching functionality for application-wide statistics and metrics.
  Uses the configured cache backend with appropriate TTL settings for 
  performance monitoring and dashboard data.

  ## Features

  - **Performance Caching**: Stores expensive statistical computations
  - **Dashboard Support**: Cached metrics for monitoring interfaces
  - **TTL Management**: Configurable expiration for fresh data
  - **Backend Agnostic**: Works with memory, Redis, or hybrid cache backends

  ## Cache Keys

  - `stats:application` - Application-wide statistics and metrics

  ## TTL Strategy

  Uses medium TTL (15 minutes) to balance data freshness with performance.
  Statistics are typically expensive to compute but don't change rapidly.

  ## Usage

      # Cache application statistics
      stats = %{
        total_users: 1500,
        total_trips: 5000,
        api_calls_today: 25000
      }
      RouteWiseApi.Caching.Statistics.put_cache(stats)

      # Retrieve cached statistics
      {:ok, stats} = RouteWiseApi.Caching.Statistics.get_cache()

  ## Integration

  Typically used by:
  - Admin dashboard endpoints
  - Monitoring and alerting systems
  - Performance tracking middleware
  - API analytics services
  """

  alias RouteWiseApi.Caching.Config

  @doc """
  Retrieves cached application statistics.

  Fetches application-wide statistics from the configured cache backend.
  Returns cached metrics for dashboards and monitoring systems.

  ## Returns

  - `{:ok, stats}` - Cached statistics map
  - `:error` - Cache miss or backend unavailable

  ## Examples

      iex> RouteWiseApi.Caching.Statistics.get_cache()
      {:ok, %{total_users: 1500, total_trips: 5000, api_calls_today: 25000}}

      iex> RouteWiseApi.Caching.Statistics.get_cache()
      :error  # Cache miss
  """
  @spec get_cache() :: {:ok, map()} | :error
  def get_cache do
    backend = Config.backend()
    backend.get("stats:application")
  end

  @doc """
  Caches application statistics with configured TTL.

  Stores application-wide statistics in the cache backend with medium TTL
  (15 minutes). Used to cache expensive statistical computations.

  ## Parameters

  - `stats` - Map containing application statistics

  ## Returns

  - `:ok` - Successfully cached
  - `{:error, reason}` - Cache operation failed

  ## Statistics Format

  Expected statistics map structure:
  ```elixir
  %{
    total_users: integer(),
    total_trips: integer(),
    active_sessions: integer(),
    api_calls_today: integer(),
    average_response_time: float(),
    cache_hit_rate: float(),
    last_updated: DateTime.t()
  }
  ```

  ## Examples

      iex> stats = %{total_users: 1500, total_trips: 5000}
      iex> RouteWiseApi.Caching.Statistics.put_cache(stats)
      :ok
  """
  @spec put_cache(map()) :: :ok | {:error, any()}
  def put_cache(stats) do
    # 15 minutes for stats
    ttl = Config.ttl(:medium)
    backend = Config.backend()

    backend.put("stats:application", stats, ttl)
  end
end
