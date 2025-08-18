defmodule RouteWiseApi.TileCache do
  @moduledoc """
  High-performance tile cache GenServer with ETS storage, TTL, and memory management.

  Optimized for OSM map tiles with binary data storage, LRU eviction, and
  compliance with OSM tile usage policies. Integrates with existing RouteWise
  caching architecture patterns.

  ## Features

  - **ETS Binary Storage**: Direct binary tile storage for minimal memory overhead
  - **TTL Management**: 7-day default TTL with automatic expiration
  - **Memory Management**: 500MB limit with LRU eviction policy
  - **Cache Statistics**: Hit rates, memory usage, and performance metrics
  - **OSM Compliance**: Respects tile server usage policies and caching guidelines

  ## Usage

      # Store a tile (z/x/y coordinates with binary PNG data)
      RouteWiseApi.TileCache.put_tile(10, 511, 383, png_binary)

      # Retrieve a tile
      {:ok, png_binary} = RouteWiseApi.TileCache.get_tile(10, 511, 383)

      # Check cache statistics
      %{hits: 1250, misses: 200, memory_mb: 45.2} = RouteWiseApi.TileCache.stats()

  ## Configuration

      config :phoenix_backend, RouteWiseApi.TileCache,
        max_memory_mb: 500,
        default_ttl_days: 7,
        cleanup_interval_minutes: 5,
        enable_statistics: true

  ## Memory Management

  Uses LRU (Least Recently Used) eviction when approaching memory limits:
  - Tracks access timestamps for each tile
  - Evicts oldest tiles first when memory limit reached
  - Monitors actual binary data size for accurate memory accounting
  """

  use GenServer
  require Logger

  @default_max_memory_mb 500
  @default_ttl_days 7
  @cleanup_interval_minutes 5

  defstruct ets_table: nil,
            access_table: nil,
            max_memory_bytes: 0,
            current_memory_bytes: 0,
            stats: %{hits: 0, misses: 0, evictions: 0, total_stored: 0}

  ## Client API

  @doc """
  Start the TileCache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store a tile in the cache.

  ## Parameters
  - `z`: Zoom level (0-19)
  - `x`: Tile X coordinate
  - `y`: Tile Y coordinate  
  - `tile_data`: Binary PNG data
  - `ttl_ms`: Optional TTL in milliseconds (default: 7 days)

  ## Examples

      RouteWiseApi.TileCache.put_tile(10, 511, 383, png_binary)
      RouteWiseApi.TileCache.put_tile(15, 1024, 768, png_binary, 86_400_000)

  """
  def put_tile(z, x, y, tile_data, ttl_ms \\ nil) do
    GenServer.call(__MODULE__, {:put_tile, z, x, y, tile_data, ttl_ms})
  end

  @doc """
  Retrieve a tile from the cache.

  Returns `{:ok, tile_data}` if found and not expired, `:error` otherwise.
  Updates access timestamp for LRU management.

  ## Examples

      {:ok, png_binary} = RouteWiseApi.TileCache.get_tile(10, 511, 383)
      :error = RouteWiseApi.TileCache.get_tile(99, 0, 0)  # Invalid coordinates

  """
  def get_tile(z, x, y) do
    GenServer.call(__MODULE__, {:get_tile, z, x, y})
  end

  @doc """
  Get cache statistics and performance metrics.

  ## Returns

      %{
        hits: 1250,           # Cache hits
        misses: 200,          # Cache misses  
        hit_rate: 0.862,      # Hit rate percentage
        evictions: 15,        # LRU evictions performed
        total_stored: 1400,   # Total tiles currently stored
        memory_mb: 45.2,      # Current memory usage in MB
        memory_usage: 0.090   # Memory usage as percentage of limit
      }

  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Clear all cached tiles and reset statistics.
  Useful for testing and debugging.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @doc """
  Get cache information for a specific tile coordinate.
  Returns metadata without retrieving the actual tile data.

  ## Examples

      {:ok, %{size_bytes: 15420, stored_at: ~U[2025-08-17], expires_at: ~U[2025-08-24]}} =
        RouteWiseApi.TileCache.tile_info(10, 511, 383)

  """
  def tile_info(z, x, y) do
    GenServer.call(__MODULE__, {:tile_info, z, x, y})
  end

  ## GenServer Implementation

  @impl true
  def init(opts) do
    # Get configuration
    config = Application.get_env(:phoenix_backend, __MODULE__, [])
    max_memory_mb = Keyword.get(opts, :max_memory_mb, Keyword.get(config, :max_memory_mb, @default_max_memory_mb))
    cleanup_interval = Keyword.get(config, :cleanup_interval_minutes, @cleanup_interval_minutes) * 60_000

    # Create ETS tables
    ets_table = :ets.new(:tile_cache, [:set, :protected, {:read_concurrency, true}])
    access_table = :ets.new(:tile_access, [:ordered_set, :protected])

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, cleanup_interval)
    Process.send_after(self(), :schedule_cleanup, cleanup_interval)

    state = %__MODULE__{
      ets_table: ets_table,
      access_table: access_table,
      max_memory_bytes: max_memory_mb * 1024 * 1024,
      current_memory_bytes: 0,
      stats: %{hits: 0, misses: 0, evictions: 0, total_stored: 0}
    }

    Logger.info("TileCache started with #{max_memory_mb}MB limit")
    {:ok, state}
  end

  @impl true
  def handle_call({:put_tile, z, x, y, tile_data, ttl_ms}, _from, state) do
    case validate_coordinates(z, x, y) do
      :ok ->
        ttl = ttl_ms || default_ttl_ms()
        expiry = System.system_time(:millisecond) + ttl
        tile_key = tile_key(z, x, y)
        access_time = System.system_time(:millisecond)
        tile_size = byte_size(tile_data)
        
        # Store tile data with metadata
        tile_entry = {tile_data, expiry, tile_size, access_time}
        :ets.insert(state.ets_table, {tile_key, tile_entry})
        :ets.insert(state.access_table, {access_time, tile_key, tile_size})
        
        # Update memory tracking
        new_memory = state.current_memory_bytes + tile_size
        new_stats = %{state.stats | total_stored: state.stats.total_stored + 1}
        
        new_state = %{state | 
          current_memory_bytes: new_memory,
          stats: new_stats
        }
        
        # Check if we need to evict tiles
        final_state = maybe_evict_tiles(new_state)
        
        {:reply, :ok, final_state}
      
      {:error, reason} ->
        Logger.warning("Invalid tile coordinates: z=#{z}, x=#{x}, y=#{y} - #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_tile, z, x, y}, _from, state) do
    case validate_coordinates(z, x, y) do
      :ok ->
        tile_key = tile_key(z, x, y)
        current_time = System.system_time(:millisecond)
        
        case :ets.lookup(state.ets_table, tile_key) do
          [{^tile_key, {tile_data, expiry, size, _old_access}}] when expiry > current_time ->
            # Update access time for LRU
            :ets.insert(state.access_table, {current_time, tile_key, size})
            :ets.insert(state.ets_table, {tile_key, {tile_data, expiry, size, current_time}})
            
            new_stats = %{state.stats | hits: state.stats.hits + 1}
            {:reply, {:ok, tile_data}, %{state | stats: new_stats}}
          
          [{^tile_key, {_tile_data, _expiry, size, access_time}}] ->
            # Expired tile - remove it
            :ets.delete(state.ets_table, tile_key)
            :ets.delete(state.access_table, access_time)
            
            new_memory = state.current_memory_bytes - size
            new_stats = %{state.stats | 
              misses: state.stats.misses + 1,
              total_stored: max(0, state.stats.total_stored - 1)
            }
            
            {:reply, :error, %{state | current_memory_bytes: new_memory, stats: new_stats}}
          
          [] ->
            # Not found
            new_stats = %{state.stats | misses: state.stats.misses + 1}
            {:reply, :error, %{state | stats: new_stats}}
        end
      
      {:error, _reason} ->
        new_stats = %{state.stats | misses: state.stats.misses + 1}
        {:reply, :error, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    total_requests = state.stats.hits + state.stats.misses
    hit_rate = if total_requests > 0, do: state.stats.hits / total_requests, else: 0.0
    memory_mb = state.current_memory_bytes / (1024 * 1024)
    memory_usage = state.current_memory_bytes / state.max_memory_bytes
    
    stats = %{
      hits: state.stats.hits,
      misses: state.stats.misses,
      hit_rate: Float.round(hit_rate, 3),
      evictions: state.stats.evictions,
      total_stored: state.stats.total_stored,
      memory_mb: Float.round(memory_mb, 2),
      memory_usage: Float.round(memory_usage, 3)
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(state.ets_table)
    :ets.delete_all_objects(state.access_table)
    
    new_state = %{state |
      current_memory_bytes: 0,
      stats: %{hits: 0, misses: 0, evictions: 0, total_stored: 0}
    }
    
    Logger.info("TileCache cleared")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:tile_info, z, x, y}, _from, state) do
    case validate_coordinates(z, x, y) do
      :ok ->
        tile_key = tile_key(z, x, y)
        
        case :ets.lookup(state.ets_table, tile_key) do
          [{^tile_key, {_tile_data, expiry, size, access_time}}] ->
            info = %{
              size_bytes: size,
              stored_at: DateTime.from_unix!(access_time, :millisecond),
              expires_at: DateTime.from_unix!(expiry, :millisecond),
              is_expired: expiry <= System.system_time(:millisecond)
            }
            {:reply, {:ok, info}, state}
          
          [] ->
            {:reply, :error, state}
        end
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    new_state = cleanup_expired_tiles(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:schedule_cleanup, state) do
    config = Application.get_env(:phoenix_backend, __MODULE__, [])
    cleanup_interval = Keyword.get(config, :cleanup_interval_minutes, @cleanup_interval_minutes) * 60_000
    Process.send_after(self(), :cleanup, cleanup_interval)
    Process.send_after(self(), :schedule_cleanup, cleanup_interval)
    {:noreply, state}
  end

  ## Private Functions

  defp validate_coordinates(z, x, y) do
    cond do
      z < 0 or z > 19 ->
        {:error, "Invalid zoom level: must be 0-19"}
      
      x < 0 or x >= :math.pow(2, z) ->
        {:error, "Invalid x coordinate for zoom level #{z}"}
      
      y < 0 or y >= :math.pow(2, z) ->
        {:error, "Invalid y coordinate for zoom level #{z}"}
      
      true ->
        :ok
    end
  end

  defp tile_key(z, x, y), do: "#{z}/#{x}/#{y}"

  defp default_ttl_ms do
    config = Application.get_env(:phoenix_backend, __MODULE__, [])
    days = Keyword.get(config, :default_ttl_days, @default_ttl_days)
    days * 24 * 60 * 60 * 1000
  end

  defp maybe_evict_tiles(state) do
    if state.current_memory_bytes > state.max_memory_bytes do
      evict_lru_tiles(state)
    else
      state
    end
  end

  defp evict_lru_tiles(state) do
    target_memory = trunc(state.max_memory_bytes * 0.8)  # Evict to 80% of limit
    evict_tiles_until_target(state, target_memory, 0)
  end

  defp evict_tiles_until_target(state, target_memory, evictions) 
       when state.current_memory_bytes <= target_memory do
    Logger.info("TileCache: Evicted #{evictions} tiles to free memory")
    new_stats = %{state.stats | evictions: state.stats.evictions + evictions}
    %{state | stats: new_stats}
  end

  defp evict_tiles_until_target(state, target_memory, evictions) do
    # Get oldest tile from access table
    case :ets.first(state.access_table) do
      :"$end_of_table" ->
        # No more tiles to evict
        state
      
      access_time ->
        case :ets.lookup(state.access_table, access_time) do
          [{^access_time, tile_key, size}] ->
            # Remove from both tables
            :ets.delete(state.ets_table, tile_key)
            :ets.delete(state.access_table, access_time)
            
            new_memory = state.current_memory_bytes - size
            new_total = max(0, state.stats.total_stored - 1)
            
            new_state = %{state |
              current_memory_bytes: new_memory,
              stats: %{state.stats | total_stored: new_total}
            }
            
            evict_tiles_until_target(new_state, target_memory, evictions + 1)
          
          [] ->
            # Entry not found, continue
            evict_tiles_until_target(state, target_memory, evictions)
        end
    end
  end

  defp cleanup_expired_tiles(state) do
    current_time = System.system_time(:millisecond)
    expired_tiles = find_expired_tiles(state.ets_table, current_time)
    
    if length(expired_tiles) > 0 do
      remove_expired_tiles(state, expired_tiles)
    else
      state
    end
  end

  defp find_expired_tiles(ets_table, current_time) do
    :ets.select(ets_table, [
      {{:"$1", {:"$2", :"$3", :"$4", :"$5"}}, 
       [{:"=<", :"$3", {:const, current_time}}],
       [{{:"$1", :"$4", :"$5"}}]}
    ])
  end

  defp remove_expired_tiles(state, expired_tiles) do
    {memory_freed, tiles_removed} = 
      Enum.reduce(expired_tiles, {0, 0}, fn {tile_key, size, access_time}, {mem_acc, count_acc} ->
        :ets.delete(state.ets_table, tile_key)
        :ets.delete(state.access_table, access_time)
        {mem_acc + size, count_acc + 1}
      end)

    new_memory = state.current_memory_bytes - memory_freed
    new_total = max(0, state.stats.total_stored - tiles_removed)
    
    Logger.debug("TileCache: Cleaned up #{tiles_removed} expired tiles, freed #{Float.round(memory_freed / 1024 / 1024, 2)}MB")
    
    %{state |
      current_memory_bytes: new_memory,
      stats: %{state.stats | total_stored: new_total}
    }
  end
end