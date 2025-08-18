defmodule RouteWiseApi.Caching.Backend.Redis do
  @moduledoc """
  Redis cache backend providing persistent, distributed caching capabilities.
  
  Optimized for production environments with Redis clusters, automatic failover,
  and seamless scaling across multiple application instances.

  ## Features

  - Persistent storage with Redis durability
  - Distributed caching across multiple app instances
  - Automatic TTL management with Redis expiration
  - Connection pooling and fault tolerance
  - Health checking with Redis PING
  - JSON serialization for complex data structures

  ## Configuration

  Configure Redis connection in your environment:

      config :phoenix_backend, RouteWiseApi.Caching.Backend.Redis,
        host: "localhost",
        port: 6379,
        database: 0,
        password: nil,
        pool_size: 10

  ## Examples

      iex> RouteWiseApi.Caching.Backend.Redis.put("key", %{data: "value"}, 5000)
      :ok

      iex> RouteWiseApi.Caching.Backend.Redis.get("key")
      {:ok, %{data: "value"}}

      iex> RouteWiseApi.Caching.Backend.Redis.health_check()
      :ok
  """

  require Logger
  alias RouteWiseApi.Caching.Config

  @behaviour RouteWiseApi.Caching.Backend

  # Redis connection process name
  @redis_name :route_wise_redis

  @doc """
  Start Redis connection pool.
  Called during application startup.
  """
  def start_link(_opts \\ []) do
    config = get_redis_config()
    
    Logger.info("🔴 Starting Redis connection: #{config[:host]}:#{config[:port]}")
    
    Redix.start_link(
      [
        host: config[:host],
        port: config[:port],
        database: config[:database],
        password: config[:password]
      ],
      name: @redis_name
    )
  end

  @doc """
  Retrieve a value from Redis cache.
  
  Returns `{:ok, value}` if key exists, `:error` if not found or on failure.
  """
  def get(key) do
    cache_key = build_cache_key(key)
    
    try do
      case Redix.command(@redis_name, ["GET", cache_key]) do
        {:ok, nil} ->
          log_debug("Redis cache MISS: #{key}")
          :error
          
        {:ok, serialized_data} ->
          case Jason.decode(serialized_data) do
            {:ok, data} ->
              log_debug("Redis cache HIT: #{key}")
              {:ok, data}
            {:error, _} ->
              Logger.warning("⚠️  Redis deserialization failed for key: #{key}")
              :error
          end
          
        {:error, reason} ->
          Logger.error("❌ Redis GET error for key #{key}: #{inspect(reason)}")
          :error
      end
    rescue
      error ->
        Logger.error("❌ Redis GET exception for key #{key}: #{Exception.message(error)}")
        :error
    end
  end

  @doc """
  Store a value in Redis cache with TTL.
  
  ## Parameters
  - key: Cache key (string)
  - value: Any serializable data structure
  - ttl_ms: Time to live in milliseconds
  
  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  def put(key, value, ttl_ms) do
    cache_key = build_cache_key(key)
    ttl_seconds = div(ttl_ms, 1000)
    
    try do
      case Jason.encode(value) do
        {:ok, serialized_data} ->
          case Redix.command(@redis_name, ["SETEX", cache_key, ttl_seconds, serialized_data]) do
            {:ok, "OK"} ->
              log_debug("Redis cache PUT: #{key} (TTL: #{ttl_seconds}s)")
              :ok
              
            {:error, reason} ->
              Logger.error("❌ Redis PUT error for key #{key}: #{inspect(reason)}")
              {:error, reason}
          end
          
        {:error, reason} ->
          Logger.error("❌ Redis serialization failed for key #{key}: #{inspect(reason)}")
          {:error, :serialization_failed}
      end
    rescue
      error ->
        Logger.error("❌ Redis PUT exception for key #{key}: #{Exception.message(error)}")
        {:error, {:exception, error}}
    end
  end

  @doc """
  Delete a value from Redis cache.
  
  Returns `:ok` regardless of whether the key existed.
  """
  def delete(key) do
    cache_key = build_cache_key(key)
    
    try do
      case Redix.command(@redis_name, ["DEL", cache_key]) do
        {:ok, _count} ->
          log_debug("Redis cache DELETE: #{key}")
          :ok
          
        {:error, reason} ->
          Logger.warning("⚠️  Redis DELETE error for key #{key}: #{inspect(reason)}")
          :ok  # Return :ok anyway as delete should be idempotent
      end
    rescue
      error ->
        Logger.warning("⚠️  Redis DELETE exception for key #{key}: #{Exception.message(error)}")
        :ok
    end
  end

  @doc """
  Clear all cache entries (development/testing only).
  
  In production, this should be used with extreme caution.
  """
  def clear do
    try do
      case Redix.command(@redis_name, ["FLUSHDB"]) do
        {:ok, "OK"} ->
          Logger.info("🗑️  Redis cache cleared")
          :ok
          
        {:error, reason} ->
          Logger.error("❌ Redis FLUSHDB error: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("❌ Redis FLUSHDB exception: #{Exception.message(error)}")
        {:error, {:exception, error}}
    end
  end

  @doc """
  Check Redis connection health.
  
  Returns `:ok` if Redis is responsive, `{:error, reason}` otherwise.
  """
  def health_check do
    try do
      case Redix.command(@redis_name, ["PING"]) do
        {:ok, "PONG"} ->
          :ok
          
        {:error, reason} ->
          Logger.error("❌ Redis health check failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("❌ Redis health check exception: #{Exception.message(error)}")
        {:error, {:exception, error}}
    end
  end

  @doc """
  Invalidate cache entries by pattern.
  
  Uses Redis SCAN and DEL for pattern-based cache invalidation.
  Pattern examples: "user:*", "places:search:*"
  """
  def invalidate_pattern(pattern) do
    cache_pattern = build_cache_key(pattern)
    
    try do
      # Use SCAN to find matching keys
      case scan_keys(cache_pattern) do
        {:ok, keys} when length(keys) > 0 ->
          case Redix.command(@redis_name, ["DEL" | keys]) do
            {:ok, count} ->
              Logger.info("🗑️  Redis invalidated #{count} keys matching pattern: #{pattern}")
              :ok
              
            {:error, reason} ->
              Logger.error("❌ Redis pattern invalidation failed: #{inspect(reason)}")
              {:error, reason}
          end
          
        {:ok, []} ->
          Logger.debug("🔍 Redis pattern invalidation: no keys found for #{pattern}")
          :ok
          
        {:error, reason} ->
          Logger.error("❌ Redis pattern scan failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("❌ Redis invalidate_pattern exception: #{Exception.message(error)}")
        {:error, {:exception, error}}
    end
  end

  @doc """
  Get Redis cache statistics.
  
  Returns metrics about Redis usage and performance.
  """
  def stats do
    try do
      # Get Redis INFO stats
      case Redix.command(@redis_name, ["INFO", "memory"]) do
        {:ok, info_output} ->
          parse_redis_stats(info_output)
          
        {:error, reason} ->
          Logger.warning("⚠️  Redis stats retrieval failed: #{inspect(reason)}")
          %{error: reason}
      end
    rescue
      error ->
        Logger.warning("⚠️  Redis stats exception: #{Exception.message(error)}")
        %{error: {:exception, error}}
    end
  end

  ## Private Functions

  defp get_redis_config do
    Application.get_env(:phoenix_backend, __MODULE__, [])
    |> Keyword.merge([
      host: System.get_env("REDIS_HOST") || "localhost",
      port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
      database: String.to_integer(System.get_env("REDIS_DATABASE") || "0"),
      password: System.get_env("REDIS_PASSWORD")
    ])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp build_cache_key(key) do
    app_prefix = "route_wise"
    env = Mix.env()
    "#{app_prefix}:#{env}:#{key}"
  end

  defp log_debug(message) do
    if Config.debug_enabled?() do
      Logger.debug(message)
    end
  end

  defp parse_redis_stats(info_output) do
    # Parse Redis INFO output to extract useful metrics
    stats = 
      info_output
      |> String.split("\r\n")
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ":") do
          [key, value] -> Map.put(acc, key, value)
          _ -> acc
        end
      end)

    %{
      used_memory: Map.get(stats, "used_memory", "0") |> String.to_integer(10),
      used_memory_human: Map.get(stats, "used_memory_human", "0B"),
      connected_clients: Map.get(stats, "connected_clients", "0") |> String.to_integer(10),
      total_commands_processed: Map.get(stats, "total_commands_processed", "0") |> String.to_integer(10),
      cache_hit_rate: calculate_hit_rate(stats),
      backend: "redis",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  rescue
    _ ->
      %{
        error: "Failed to parse Redis stats",
        backend: "redis",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
  end

  defp calculate_hit_rate(stats) do
    hits = Map.get(stats, "keyspace_hits", "0") |> String.to_integer(10)
    misses = Map.get(stats, "keyspace_misses", "0") |> String.to_integer(10)
    
    total = hits + misses
    if total > 0 do
      Float.round(hits / total * 100, 2)
    else
      0.0
    end
  end

  defp scan_keys(pattern) do
    scan_keys(pattern, "0", [])
  end

  defp scan_keys(pattern, cursor, acc) do
    case Redix.command(@redis_name, ["SCAN", cursor, "MATCH", pattern]) do
      {:ok, [next_cursor, keys]} ->
        new_acc = acc ++ keys
        if next_cursor == "0" do
          {:ok, new_acc}
        else
          scan_keys(pattern, next_cursor, new_acc)
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end