defmodule RouteWiseApi.Caching.Backend.Memory do
  @moduledoc """
  In-memory cache backend using the existing RouteWiseApi.Cache GenServer.
  
  Optimized for development with debugging features and fault tolerance.
  Provides a simple, fast cache implementation suitable for single-node
  development environments.

  ## Features

  - Debug logging for cache operations
  - Fault tolerance with error recovery
  - Health checking with functional tests
  - Memory usage monitoring
  - Process status validation

  ## Configuration

  Configure debug mode through `RouteWiseApi.Caching.Config.debug_enabled?/0`.

  ## Examples

      iex> RouteWiseApi.Caching.Backend.Memory.put("key", "value", 5000)
      :ok

      iex> RouteWiseApi.Caching.Backend.Memory.get("key")
      {:ok, "value"}

      iex> RouteWiseApi.Caching.Backend.Memory.health_check()
      :ok
  """
  @behaviour RouteWiseApi.Caching.Backend

  alias RouteWiseApi.Cache
  alias RouteWiseApi.Caching.Config
  require Logger

  @doc """
  Retrieves a value from the memory cache.

  Logs cache hits/misses when debug mode is enabled.
  Returns `:error` if the key is not found or cache is unavailable.

  ## Parameters

  - `key` - Cache key (typically a string)

  ## Returns

  - `{:ok, value}` - Cache hit with stored value
  - `:error` - Cache miss or error
  """
  @spec get(any()) :: {:ok, any()} | :error
  @impl true
  def get(key) do
    case Cache.get(key) do
      # Pattern preserves exact return value from Cache.get/1 for transparency
      # Could be simplified to {:ok, data} -> {:ok, data} pattern
      {:ok, _data} = result ->
        if Config.debug_enabled?() do
          Logger.debug("Cache HIT: #{key}")
        end

        result

      :error ->
        if Config.debug_enabled?() do
          Logger.debug("Cache MISS: #{key}")
        end

        :error
    end
  rescue
    error ->
      Logger.warning("Memory cache get failed for #{key}: #{inspect(error)}")
      :error
  end

  @doc """
  Stores a value in the memory cache with TTL.

  Logs cache operations when debug mode is enabled.
  Handles cache failures gracefully with error logging.

  ## Parameters

  - `key` - Cache key
  - `value` - Value to store
  - `ttl_ms` - Time-to-live in milliseconds

  ## Returns

  - `:ok` - Successfully stored
  - `{:error, reason}` - Storage failed
  """
  @spec put(any(), any(), non_neg_integer()) :: :ok | {:error, atom()}
  @impl true
  def put(key, value, ttl_ms) do
    case Cache.put(key, value, ttl_ms) do
      :ok ->
        if Config.debug_enabled?() do
          Logger.debug("Cache PUT: #{key} (TTL: #{ttl_ms}ms)")
        end

        :ok

      error ->
        Logger.warning("Memory cache put failed for #{key}: #{inspect(error)}")
        error
    end
  rescue
    error ->
      Logger.error("Memory cache put crashed for #{key}: #{inspect(error)}")
      {:error, :cache_unavailable}
  end

  @impl true
  def delete(key) do
    case Cache.delete(key) do
      :ok ->
        if Config.debug_enabled?() do
          Logger.debug("Cache DELETE: #{key}")
        end

        :ok

      error ->
        Logger.warning("Memory cache delete failed for #{key}: #{inspect(error)}")
        # Return :ok for idempotent behavior
        :ok
    end
  rescue
    error ->
      Logger.error("Memory cache delete crashed for #{key}: #{inspect(error)}")
      # Still return :ok for idempotent behavior
      :ok
  end

  @impl true
  def clear do
    case Cache.clear() do
      :ok ->
        if Config.debug_enabled?() do
          Logger.debug("Cache CLEAR: all entries")
        end

        :ok

      error ->
        Logger.warning("Memory cache clear failed: #{inspect(error)}")
        error
    end
  rescue
    error ->
      Logger.error("Memory cache clear crashed: #{inspect(error)}")
      {:error, :cache_unavailable}
  end

  @impl true
  def stats do
    try do
      base_stats = Cache.stats()

      Map.merge(base_stats, %{
        backend: "memory",
        environment: Mix.env(),
        debug_enabled: Config.debug_enabled?(),
        health_status: :healthy,
        memory_usage: :erlang.memory(:total),
        process_alive: Process.alive?(Process.whereis(Cache))
      })
    rescue
      error ->
        Logger.error("Memory cache stats failed: #{inspect(error)}")

        %{
          backend: "memory",
          health_status: :unhealthy,
          error: inspect(error)
        }
    end
  end

  @doc """
  Performs comprehensive health check of the memory cache.

  Tests cache process availability and basic read/write functionality
  with a temporary test key.

  ## Returns

  - `:ok` - Cache is healthy and functional
  - `{:error, reason}` - Health check failed

  ## Error Reasons

  - `:process_not_found` - Cache GenServer not found
  - `:process_dead` - Cache process exists but not alive
  - `:data_corruption` - Data integrity check failed
  - `:read_failure` - Cannot read from cache
  - `{:write_failure, error}` - Cannot write to cache
  """
  @spec health_check() :: :ok | {:error, atom() | {atom(), any()}}
  @impl true
  def health_check do
    case Process.whereis(Cache) do
      nil ->
        {:error, :process_not_found}

      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          # Test basic functionality
          test_key = "health_check_#{System.monotonic_time()}"

          case put(test_key, :test_value, 1000) do
            :ok ->
              case get(test_key) do
                {:ok, :test_value} ->
                  delete(test_key)
                  :ok

                {:ok, _other} ->
                  {:error, :data_corruption}

                :error ->
                  {:error, :read_failure}
              end

            error ->
              {:error, {:write_failure, error}}
          end
        else
          {:error, :process_dead}
        end
    end
  end

  @impl true
  def invalidate_pattern(pattern) do
    # Memory backend doesn't support pattern matching efficiently
    # This is a simple implementation for development
    if String.contains?(pattern, "*") do
      Logger.debug("Pattern invalidation not efficiently supported in memory backend: #{pattern}")
      :ok
    else
      delete(pattern)
    end
  end
end