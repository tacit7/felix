defmodule RouteWiseApi.Caching.Backend do
  @moduledoc """
  Behavior definition for cache backends following OTP patterns.

  Defines the contract that all cache backends must implement,
  enabling pluggable cache strategies with proper fault tolerance.
  Each backend must handle its own supervision and error recovery.
  """

  @doc """
  Get value from cache by key.
  Returns {:ok, value} on cache hit, :error on cache miss.
  Backend must handle connection failures gracefully.
  """
  @callback get(key :: binary()) :: {:ok, any()} | :error

  @doc """
  Put value in cache with TTL in milliseconds.
  Returns :ok on success, {:error, reason} on failure.
  Backend should not crash on write failures.
  """
  @callback put(key :: binary(), value :: any(), ttl_ms :: integer()) ::
              :ok | {:error, any()}

  @doc """
  Delete key from cache.
  Returns :ok regardless of whether key existed.
  Should be idempotent and crash-safe.
  """
  @callback delete(key :: binary()) :: :ok

  @doc """
  Clear all cache entries managed by this backend.
  Returns :ok on success, may return {:error, reason} on failure.
  """
  @callback clear() :: :ok | {:error, any()}

  @doc """
  Get cache statistics and health information.
  Should include connection status, memory usage, hit rates.
  Must not crash if backend is unavailable.
  """
  @callback stats() :: map()

  @doc """
  Health check for the backend.
  Returns :ok if healthy, {:error, reason} if unhealthy.
  Used by supervision trees for restart decisions.
  """
  @callback health_check() :: :ok | {:error, any()}

  @doc """
  Invalidate cache entries by pattern.
  Used for distributed cache invalidation strategies.
  Pattern examples: "user:*", "places:search:*"
  """
  @callback invalidate_pattern(pattern :: binary()) :: :ok | {:error, any()}
end
