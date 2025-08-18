defmodule RouteWiseApi.Cache do
  @moduledoc """
  In-memory cache GenServer with TTL support and automatic cleanup.

  Provides fast, local caching for API responses and computed data.
  Designed for development and single-node deployments. For production
  distributed systems, consider Redis or other persistent cache solutions.

  ## Features

  - **TTL Support**: Automatic expiration with configurable time-to-live
  - **Timer Management**: Process timers for immediate expiration handling
  - **Periodic Cleanup**: Background cleanup of expired entries every minute
  - **Statistics**: Cache hit/miss metrics and key counts
  - **Memory Efficient**: Automatic cleanup prevents unbounded growth

  ## Usage

      # Store with 5 second TTL
      RouteWiseApi.Cache.put("key", "value", 5_000)

      # Retrieve
      {:ok, "value"} = RouteWiseApi.Cache.get("key")

      # After TTL expires
      :error = RouteWiseApi.Cache.get("key")

  ## Internal Structure

  Maintains two maps:
  - `data`: Stores `{value, expiry_timestamp}` tuples
  - `timers`: Tracks process timers for active keys

  ## Performance Characteristics

  - O(1) get/put/delete operations
  - O(n) cleanup operations (every minute)
  - Memory usage grows with stored data until cleanup
  """

  use GenServer
  require Logger

  @cleanup_interval 60_000  # 1 minute

  defstruct data: %{}, timers: %{}

  ## Client API

  @doc """
  Starts the cache GenServer.

  ## Parameters

  - `opts` - GenServer options (optional)

  ## Returns

  - `{:ok, pid}` - GenServer started successfully
  - `{:error, reason}` - Start failed
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieves a value from the cache.

  Returns the cached value if the key exists and hasn't expired.
  Automatically cleans up expired keys on access.

  ## Parameters

  - `key` - Cache key to retrieve

  ## Returns

  - `{:ok, value}` - Cache hit with stored value
  - `:error` - Cache miss or expired key
  """
  @spec get(any()) :: {:ok, any()} | :error
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Stores a value in the cache with TTL.

  Sets up automatic expiration using process timers. Overwrites
  existing values and cancels previous timers for the same key.

  ## Parameters

  - `key` - Cache key
  - `value` - Value to store
  - `ttl_ms` - Time-to-live in milliseconds

  ## Returns

  - `:ok` - Successfully stored
  """
  @spec put(any(), any(), non_neg_integer()) :: :ok
  def put(key, value, ttl_ms) do
    GenServer.call(__MODULE__, {:put, key, value, ttl_ms})
  end

  @doc """
  Removes a key from the cache.

  Cancels associated timers and immediately removes the key.
  Idempotent operation - safe to call on non-existent keys.

  ## Parameters

  - `key` - Cache key to delete

  ## Returns

  - `:ok` - Always succeeds
  """
  @spec delete(any()) :: :ok
  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  @doc """
  Clears all cached entries and timers.

  Removes all data and cancels all active timers. Useful for
  testing and memory management.

  ## Returns

  - `:ok` - Cache cleared successfully
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Returns cache statistics and metrics.

  Provides insights into cache performance and memory usage.
  Useful for monitoring and debugging.

  ## Returns

  A map containing:
  - `total_keys` - Total number of cached keys
  - `expired_keys` - Number of expired but not yet cleaned keys
  - `active_timers` - Number of active expiration timers
  """
  @spec stats() :: %{
    total_keys: non_neg_integer(),
    expired_keys: non_neg_integer(),
    active_timers: non_neg_integer()
  }
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting RouteWiseApi.Cache")
    schedule_cleanup()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case Map.get(state.data, key) do
      {value, expiry} ->
        if System.monotonic_time(:millisecond) < expiry do
          {:reply, {:ok, value}, state}
        else
          # Key expired, clean up
          new_state = delete_key(state, key)
          {:reply, :error, new_state}
        end
      nil ->
        {:reply, :error, state}
    end
  end

  @impl true
  def handle_call({:put, key, value, ttl_ms}, _from, state) do
    expiry = System.monotonic_time(:millisecond) + ttl_ms
    
    # Cancel existing timer if any
    new_state = cancel_timer(state, key)
    
    # Set up new timer
    timer_ref = Process.send_after(self(), {:expire, key}, ttl_ms)
    
    updated_state = %{new_state | 
      data: Map.put(new_state.data, key, {value, expiry}),
      timers: Map.put(new_state.timers, key, timer_ref)
    }
    
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    new_state = delete_key(state, key)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    # Cancel all timers
    Enum.each(state.timers, fn {_key, timer_ref} ->
      Process.cancel_timer(timer_ref)
    end)
    
    new_state = %__MODULE__{}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    now = System.monotonic_time(:millisecond)
    
    stats = %{
      total_keys: map_size(state.data),
      expired_keys: Enum.count(state.data, fn {_key, {_value, expiry}} -> 
        now >= expiry 
      end),
      active_timers: map_size(state.timers)
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_info({:expire, key}, state) do
    new_state = delete_key(state, key)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    new_state = cleanup_expired(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  ## Private Functions

  defp delete_key(state, key) do
    # Cancel timer if exists
    new_state = cancel_timer(state, key)
    
    %{new_state | 
      data: Map.delete(new_state.data, key)
    }
  end

  defp cancel_timer(state, key) do
    case Map.get(state.timers, key) do
      nil -> state
      timer_ref ->
        Process.cancel_timer(timer_ref)
        %{state | timers: Map.delete(state.timers, key)}
    end
  end

  defp cleanup_expired(state) do
    now = System.monotonic_time(:millisecond)
    
    {expired_keys, active_data} = 
      Enum.split_with(state.data, fn {_key, {_value, expiry}} -> 
        now >= expiry 
      end)
    
    # Cancel timers for expired keys
    expired_timers = 
      expired_keys
      |> Enum.map(fn {key, _} -> key end)
      |> Enum.reduce(state.timers, fn key, timers ->
        case Map.get(timers, key) do
          nil -> timers
          timer_ref ->
            Process.cancel_timer(timer_ref)
            Map.delete(timers, key)
        end
      end)
    
    if length(expired_keys) > 0 do
      Logger.debug("Cache cleanup: removed #{length(expired_keys)} expired keys")
    end
    
    %{state | 
      data: Map.new(active_data),
      timers: expired_timers
    }
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end