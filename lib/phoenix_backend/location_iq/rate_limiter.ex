defmodule RouteWiseApi.LocationIQ.RateLimiter do
  @moduledoc """
  Token bucket rate limiter for LocationIQ API requests.
  
  Implements a token bucket algorithm to prevent API quota exhaustion
  and manage request rates across different time windows.
  
  Features:
  - Token bucket algorithm with burst capacity
  - Multiple time windows (per second, minute, hour, day)
  - ETS-based storage for performance
  - Automatic token replenishment
  - Graceful degradation on limit violations
  """
  
  use GenServer
  require Logger

  @table_name :location_iq_rate_limiter
  @refill_interval 1000  # Refill tokens every second

  # Default rate limits (conservative for free tier)
  @default_limits %{
    requests_per_second: 2,
    requests_per_minute: 60,
    requests_per_hour: 1000,
    requests_per_day: 5000
  }

  defmodule Bucket do
    @moduledoc false
    defstruct [:key, :tokens, :capacity, :last_refill, :refill_rate]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if a request is allowed and consume a token if so.

  Returns `{:ok, remaining}` if request is allowed, 
  `{:error, :rate_limited, retry_after}` if rate limited.

  ## Examples
      iex> check_rate_limit("autocomplete", "user_123")
      {:ok, 59}

      iex> check_rate_limit("autocomplete", "user_123") # after hitting limit
      {:error, :rate_limited, 30}
  """
  def check_rate_limit(api_endpoint, identifier \\ "global") do
    GenServer.call(__MODULE__, {:check_rate_limit, api_endpoint, identifier})
  end

  @doc """
  Clear all rate limiter state and restart with fresh buckets.
  
  Useful for recovering from corrupted ETS data.
  """
  def reset_state() do
    GenServer.call(__MODULE__, :reset_state)
  end

  @doc """
  Get current rate limit status without consuming tokens.

  ## Examples
      iex> get_status("autocomplete")
      %{
        per_second: {tokens: 2, capacity: 2, next_refill: ~U[2024-08-06 19:30:45Z]},
        per_minute: {tokens: 58, capacity: 60, next_refill: ~U[2024-08-06 19:31:00Z]}
      }
  """
  def get_status(api_endpoint, identifier \\ "global") do
    GenServer.call(__MODULE__, {:get_status, api_endpoint, identifier})
  end

  @doc """
  Reset rate limits for testing or emergency situations.
  """
  def reset_limits(api_endpoint \\ :all, identifier \\ "global") do
    GenServer.call(__MODULE__, {:reset_limits, api_endpoint, identifier})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    # Create ETS table for fast token bucket storage
    :ets.new(@table_name, [:set, :public, :named_table])
    
    # Schedule periodic token refill
    :timer.send_interval(@refill_interval, :refill_tokens)
    
    limits = Keyword.get(opts, :limits, @default_limits)
    
    {:ok, %{limits: limits}}
  end

  @impl true
  def handle_call({:check_rate_limit, api_endpoint, identifier}, _from, state) do
    now = DateTime.utc_now()
    
    # Check all time windows
    results = Enum.map([:per_second, :per_minute, :per_hour, :per_day], fn window ->
      bucket_key = build_bucket_key(api_endpoint, identifier, window)
      check_and_consume_token(bucket_key, window, now, state.limits)
    end)
    
    # If any window is rate limited, return error with shortest retry time
    case Enum.find(results, fn {status, _} -> status == :error end) do
      nil ->
        # All windows allowed - return minimum remaining tokens
        min_remaining = results |> Enum.map(fn {:ok, remaining} -> remaining end) |> Enum.min()
        {:reply, {:ok, min_remaining}, state}
      
      {:error, _retry_after} ->
        # Find shortest retry time across all limited windows
        retry_times = results 
          |> Enum.filter(fn {status, _} -> status == :error end)
          |> Enum.map(fn {_, time} -> time end)
        
        shortest_retry = Enum.min(retry_times)
        {:reply, {:error, :rate_limited, shortest_retry}, state}
    end
  end

  @impl true
  def handle_call({:get_status, api_endpoint, identifier}, _from, state) do
    now = DateTime.utc_now()
    
    status = [:per_second, :per_minute, :per_hour, :per_day]
      |> Enum.map(fn window ->
        bucket_key = build_bucket_key(api_endpoint, identifier, window)
        bucket = get_or_create_bucket(bucket_key, window, now, state.limits)
        
        next_refill = calculate_next_refill(bucket, window)
        
        {window, %{
          tokens: bucket.tokens,
          capacity: bucket.capacity,
          next_refill: next_refill
        }}
      end)
      |> Enum.into(%{})
    
    {:reply, status, state}
  end

  @impl true
  def handle_call(:reset_state, _from, state) do
    # Clear all ETS data and restart fresh
    :ets.delete_all_objects(@table_name)
    Logger.info("Rate limiter state reset - all buckets cleared")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:reset_limits, api_endpoint, identifier}, _from, state) do
    case api_endpoint do
      :all ->
        :ets.delete_all_objects(@table_name)
        Logger.info("Reset all rate limits")
      
      endpoint ->
        pattern = build_bucket_key(endpoint, identifier, :_)
        :ets.match_delete(@table_name, {pattern, :_})
        Logger.info("Reset rate limits for #{endpoint}/#{identifier}")
    end
    
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:refill_tokens, state) do
    now = DateTime.utc_now()
    refill_all_buckets(now, state.limits)
    {:noreply, state}
  end

  # Private functions

  defp build_bucket_key(api_endpoint, identifier, window) do
    "#{api_endpoint}:#{identifier}:#{window}"
  end

  defp check_and_consume_token(bucket_key, window, now, limits) do
    bucket = get_or_create_bucket(bucket_key, window, now, limits)
    
    if bucket.tokens > 0 do
      # Consume token and update bucket
      updated_bucket = %{bucket | tokens: bucket.tokens - 1}
      :ets.insert(@table_name, {bucket_key, updated_bucket})
      
      {:ok, updated_bucket.tokens}
    else
      # Rate limited - calculate retry after time
      retry_after = calculate_retry_after(bucket, window)
      {:error, retry_after}
    end
  end

  defp get_or_create_bucket(bucket_key, window, now, limits) do
    case :ets.lookup(@table_name, bucket_key) do
      [{^bucket_key, bucket}] ->
        refill_bucket(bucket, now)
      
      [] ->
        create_bucket(bucket_key, window, now, limits)
    end
  end

  defp create_bucket(bucket_key, window, now, limits) do
    capacity = get_window_capacity(window, limits)
    refill_rate = get_refill_rate(window, capacity)
    
    bucket = %Bucket{
      key: bucket_key,
      tokens: capacity,
      capacity: capacity,
      last_refill: now,
      refill_rate: refill_rate
    }
    
    :ets.insert(@table_name, {bucket_key, bucket})
    bucket
  end

  defp refill_bucket(bucket, now) do
    # Validate that last_refill is a DateTime struct, not a corrupted tuple
    last_refill = case bucket.last_refill do
      %DateTime{} = dt -> dt
      _ -> 
        Logger.warning("Corrupted last_refill timestamp in bucket #{bucket.key}, resetting to now")
        now
    end
    
    seconds_elapsed = DateTime.diff(now, last_refill, :second)
    
    if seconds_elapsed > 0 do
      # Calculate tokens to add based on elapsed time and refill rate
      tokens_to_add = min(seconds_elapsed * bucket.refill_rate, 
                         bucket.capacity - bucket.tokens)
      
      updated_bucket = %{bucket | 
        tokens: bucket.tokens + tokens_to_add,
        last_refill: now
      }
      
      :ets.insert(@table_name, {bucket.key, updated_bucket})
      updated_bucket
    else
      # Update last_refill even if no tokens added, in case it was corrupted
      updated_bucket = %{bucket | last_refill: now}
      :ets.insert(@table_name, {bucket.key, updated_bucket})
      updated_bucket
    end
  end

  defp refill_all_buckets(now, _limits) do
    # Refill all buckets in ETS table
    :ets.tab2list(@table_name)
    |> Enum.each(fn {bucket_key, bucket} ->
      refilled_bucket = refill_bucket(bucket, now)
      :ets.insert(@table_name, {bucket_key, refilled_bucket})
    end)
  end

  defp get_window_capacity(window, limits) do
    case window do
      :per_second -> limits.requests_per_second
      :per_minute -> limits.requests_per_minute
      :per_hour -> limits.requests_per_hour  
      :per_day -> limits.requests_per_day
    end
  end

  defp get_refill_rate(window, capacity) do
    case window do
      :per_second -> capacity    # Refill all tokens every second
      :per_minute -> capacity / 60  # Distribute across 60 seconds
      :per_hour -> capacity / 3600  # Distribute across 3600 seconds
      :per_day -> capacity / 86400  # Distribute across 86400 seconds
    end
  end

  defp calculate_retry_after(_bucket, window) do
    case window do
      :per_second -> 1
      :per_minute -> 60 - DateTime.utc_now().second
      :per_hour -> 3600 - (DateTime.utc_now().minute * 60 + DateTime.utc_now().second)
      :per_day -> 
        now = DateTime.utc_now()
        seconds_today = now.hour * 3600 + now.minute * 60 + now.second
        86400 - seconds_today
    end
  end

  defp calculate_next_refill(bucket, window) do
    # Validate that last_refill is a DateTime struct, not a corrupted tuple
    last_refill = case bucket.last_refill do
      %DateTime{} = dt -> dt
      _ -> 
        Logger.warning("Corrupted last_refill timestamp in calculate_next_refill for bucket #{bucket.key}")
        DateTime.utc_now()
    end
    
    case window do
      :per_second ->
        DateTime.add(last_refill, 1, :second)
      :per_minute ->
        next_minute = DateTime.utc_now() |> DateTime.truncate(:minute)
        DateTime.add(next_minute, 60, :second)
      :per_hour ->
        next_hour = DateTime.utc_now() |> DateTime.truncate(:hour)  
        DateTime.add(next_hour, 3600, :second)
      :per_day ->
        next_day = DateTime.utc_now() |> DateTime.to_date() |> Date.add(1)
        DateTime.new!(next_day, ~T[00:00:00])
    end
  end
end