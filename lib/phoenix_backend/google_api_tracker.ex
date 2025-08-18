defmodule RouteWiseApi.GoogleAPITracker do
  @moduledoc """
  Lightweight API usage tracker for Google Places API.
  
  Tracks calls in-memory using ETS and provides rate limiting.
  Resets monthly based on Google's billing cycle.
  """
  
  use GenServer
  require Logger
  
  alias RouteWiseApi.GoogleAPIUsage

  # Google Places API limits
  @monthly_quota 200_000  # Adjust based on your plan
  @daily_quota 10_000     # Conservative daily limit
  @requests_per_second 100 # Google's default QPS limit
  
  # Sync interval - persist to DB every 5 minutes
  @sync_interval_ms 5 * 60 * 1000

  @table_name :google_api_usage

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Track a Google Places API call.
  Returns :ok if under limits, {:error, reason} if over limits.
  """
  def track_call(endpoint_type \\ :places) do
    GenServer.call(__MODULE__, {:track_call, endpoint_type})
  end

  @doc """
  Check current month's usage.
  Returns %{calls: count, quota: limit, percentage: usage_percent}
  """
  def get_monthly_usage do
    GenServer.call(__MODULE__, :get_monthly_usage)
  end

  @doc """
  Check current day's usage.
  """
  def get_daily_usage do
    GenServer.call(__MODULE__, :get_daily_usage)
  end

  @doc """
  Get detailed usage breakdown by endpoint type.
  """
  def get_usage_breakdown do
    GenServer.call(__MODULE__, :get_usage_breakdown)
  end

  @doc """
  Check if we can make a call without hitting limits.
  """
  def can_make_call? do
    case GenServer.call(__MODULE__, :check_limits) do
      :ok -> true
      {:error, _reason} -> false
    end
  end

  @doc """
  Reset usage (mainly for testing).
  """
  def reset_usage do
    GenServer.call(__MODULE__, :reset_usage)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for tracking
    :ets.new(@table_name, [:set, :named_table, :public])
    
    # Load existing data from database
    load_from_database()
    
    # Initialize current month/day counters if not loaded
    init_counters()
    
    # Schedule periodic database sync
    schedule_sync()
    
    Logger.info("🔍 Google API Tracker started - Monthly quota: #{@monthly_quota}")
    {:ok, %{last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:track_call, endpoint_type}, _from, state) do
    case check_rate_limits() do
      :ok ->
        increment_counters(endpoint_type)
        Logger.debug("📊 API call tracked: #{endpoint_type}")
        {:reply, :ok, state}
      
      {:error, reason} = error ->
        Logger.warning("🚫 API call blocked: #{reason}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_monthly_usage, _from, state) do
    month_key = get_month_key()
    calls = get_counter(month_key, 0)
    
    usage = %{
      calls: calls,
      quota: @monthly_quota,
      percentage: round(calls / @monthly_quota * 100),
      remaining: @monthly_quota - calls
    }
    
    {:reply, usage, state}
  end

  @impl true
  def handle_call(:get_daily_usage, _from, state) do
    day_key = get_day_key()
    calls = get_counter(day_key, 0)
    
    usage = %{
      calls: calls,
      quota: @daily_quota,
      percentage: round(calls / @daily_quota * 100),
      remaining: @daily_quota - calls
    }
    
    {:reply, usage, state}
  end

  @impl true
  def handle_call(:get_usage_breakdown, _from, state) do
    month_key = get_month_key()
    day_key = get_day_key()
    
    breakdown = %{
      monthly: %{
        total: get_counter(month_key, 0),
        places: get_counter("#{month_key}_places", 0),
        autocomplete: get_counter("#{month_key}_autocomplete", 0),
        details: get_counter("#{month_key}_details", 0),
        photos: get_counter("#{month_key}_photos", 0)
      },
      daily: %{
        total: get_counter(day_key, 0),
        places: get_counter("#{day_key}_places", 0),
        autocomplete: get_counter("#{day_key}_autocomplete", 0),
        details: get_counter("#{day_key}_details", 0),
        photos: get_counter("#{day_key}_photos", 0)
      }
    }
    
    {:reply, breakdown, state}
  end

  @impl true
  def handle_call(:check_limits, _from, state) do
    result = check_rate_limits()
    {:reply, result, state}
  end

  @impl true
  def handle_call(:reset_usage, _from, state) do
    :ets.delete_all_objects(@table_name)
    init_counters()
    Logger.info("🔄 API usage counters reset")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:force_sync, _from, state) do
    sync_to_database()
    {:reply, :ok, %{state | last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:sync_to_database, state) do
    sync_to_database()
    schedule_sync()
    {:noreply, %{state | last_sync: DateTime.utc_now()}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Functions

  defp init_counters do
    month_key = get_month_key()
    day_key = get_day_key()
    
    # Initialize if not exists
    unless counter_exists?(month_key), do: set_counter(month_key, 0)
    unless counter_exists?(day_key), do: set_counter(day_key, 0)
  end

  defp get_month_key do
    %{year: year, month: month} = DateTime.utc_now()
    "month_#{year}_#{String.pad_leading(to_string(month), 2, "0")}"
  end

  defp get_day_key do
    %{year: year, month: month, day: day} = DateTime.utc_now()
    "day_#{year}_#{String.pad_leading(to_string(month), 2, "0")}_#{String.pad_leading(to_string(day), 2, "0")}"
  end

  defp check_rate_limits do
    month_key = get_month_key()
    day_key = get_day_key()
    
    monthly_calls = get_counter(month_key, 0)
    daily_calls = get_counter(day_key, 0)
    
    cond do
      monthly_calls >= @monthly_quota ->
        {:error, "Monthly quota exceeded (#{monthly_calls}/#{@monthly_quota})"}
      
      daily_calls >= @daily_quota ->
        {:error, "Daily quota exceeded (#{daily_calls}/#{@daily_quota})"}
      
      true ->
        :ok
    end
  end

  defp increment_counters(endpoint_type) do
    month_key = get_month_key()
    day_key = get_day_key()
    
    # Increment total counters
    increment_counter(month_key)
    increment_counter(day_key)
    
    # Increment endpoint-specific counters
    increment_counter("#{month_key}_#{endpoint_type}")
    increment_counter("#{day_key}_#{endpoint_type}")
  end

  defp get_counter(key, default \\ 0) do
    case :ets.lookup(@table_name, key) do
      [{^key, value}] -> value
      [] -> default
    end
  end

  defp set_counter(key, value) do
    :ets.insert(@table_name, {key, value})
  end

  defp increment_counter(key) do
    :ets.update_counter(@table_name, key, 1, {key, 0})
  end

  defp counter_exists?(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, _}] -> true
      [] -> false
    end
  end

  ## Database Persistence Functions

  defp load_from_database do
    try do
      ets_data = GoogleAPIUsage.load_to_ets()
      
      Enum.each(ets_data, fn {key, value} ->
        set_counter(key, value)
      end)
      
      Logger.info("📥 Loaded API usage data from database")
    rescue
      error ->
        Logger.warning("⚠️ Failed to load API usage from database: #{inspect(error)}")
    end
  end

  defp sync_to_database do
    try do
      # Get all ETS data
      ets_data = :ets.tab2list(@table_name) |> Enum.into(%{})
      
      # Filter for daily counters with endpoint types (format: day_YYYY_MM_DD_endpoint)
      daily_endpoint_data = 
        ets_data
        |> Enum.filter(fn {key, _value} -> 
          is_binary(key) and String.starts_with?(key, "day_") and String.contains?(key, "_") and not String.ends_with?(key, "_total")
        end)
        |> Enum.reduce(%{}, fn {key, count}, acc ->
          case parse_daily_endpoint_key(key) do
            {:ok, date, endpoint_type} ->
              Map.put(acc, {date, endpoint_type}, count)
            _ ->
              acc
          end
        end)
      
      # Sync each daily endpoint count to database
      Enum.each(daily_endpoint_data, fn {{date, endpoint_type}, count} ->
        if count > 0 do
          case GoogleAPIUsage.get_or_create_usage(date, endpoint_type) do
            {:ok, usage} ->
              if usage.call_count < count do
                increment = count - usage.call_count
                GoogleAPIUsage.increment_usage(date, endpoint_type, increment)
              end
            {:error, _reason} ->
              :ignore
          end
        end
      end)
      
      Logger.debug("💾 Synced API usage to database")
    rescue
      error ->
        Logger.warning("⚠️ Failed to sync API usage to database: #{inspect(error)}")
    end
  end

  defp schedule_sync do
    Process.send_after(self(), :sync_to_database, @sync_interval_ms)
  end

  defp parse_daily_endpoint_key("day_" <> rest) do
    case String.split(rest, "_") do
      [year, month, day, endpoint_type] ->
        with {year_int, ""} <- Integer.parse(year),
             {month_int, ""} <- Integer.parse(month),
             {day_int, ""} <- Integer.parse(day),
             {:ok, date} <- Date.new(year_int, month_int, day_int) do
          {:ok, date, endpoint_type}
        else
          _ -> :error
        end
      _ -> :error
    end
  end

  defp parse_daily_endpoint_key(_), do: :error

  ## Helper Functions for Integration

  @doc """
  Convenience function to track and check if a Google API call can proceed.
  Use this in your API clients before making calls.
  """
  def track_and_proceed(endpoint_type, fun) when is_function(fun, 0) do
    case track_call(endpoint_type) do
      :ok ->
        fun.()
      
      {:error, reason} ->
        Logger.warning("🚫 Google API call blocked: #{reason}")
        {:error, {:rate_limited, reason}}
    end
  end

  @doc """
  Get a summary string for logging.
  """
  def usage_summary do
    monthly = get_monthly_usage()
    daily = get_daily_usage()
    
    "📊 Google API Usage - Month: #{monthly.calls}/#{monthly.quota} (#{monthly.percentage}%) | Day: #{daily.calls}/#{daily.quota} (#{daily.percentage}%)"
  end
  
  @doc """
  Force immediate sync to database (useful for testing or shutdown).
  """
  def force_sync do
    GenServer.call(__MODULE__, :force_sync)
  end
end