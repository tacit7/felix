defmodule RouteWiseApi.ScrapingMonitor do
  @moduledoc """
  Monitoring and analytics for TripAdvisor scraping operations.
  Tracks usage patterns and prevents abuse.
  """
  
  use GenServer
  require Logger

  @daily_request_limit 1000  # Max requests per day to TripAdvisor
  @hourly_request_limit 100  # Max requests per hour

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_request(location) do
    GenServer.cast(__MODULE__, {:record_request, location})
  end

  def get_usage_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end

  def can_scrape?(location) do
    GenServer.call(__MODULE__, {:can_scrape, location})
  end

  @impl true
  def init(_opts) do
    # Schedule daily cleanup
    :timer.send_interval(:timer.hours(24), self(), :daily_cleanup)
    
    {:ok, %{
      daily_requests: 0,
      hourly_requests: 0,
      last_hour_reset: DateTime.utc_now(),
      last_day_reset: DateTime.utc_now(),
      location_requests: %{}, # Track per-location requests
      blocked_locations: MapSet.new() # Temporarily blocked locations
    }}
  end

  @impl true
  def handle_cast({:record_request, location}, state) do
    new_state = %{
      state
      | daily_requests: state.daily_requests + 1,
        hourly_requests: state.hourly_requests + 1,
        location_requests: Map.update(state.location_requests, location, 1, &(&1 + 1))
    }

    # Check if we're hitting limits
    if new_state.daily_requests > @daily_request_limit do
      Logger.warn("🚨 Daily TripAdvisor request limit exceeded: #{new_state.daily_requests}")
    end

    if new_state.hourly_requests > @hourly_request_limit do
      Logger.warn("⚠️ Hourly TripAdvisor request limit exceeded: #{new_state.hourly_requests}")
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      daily_requests: state.daily_requests,
      hourly_requests: state.hourly_requests,
      daily_limit: @daily_request_limit,
      hourly_limit: @hourly_request_limit,
      top_locations: get_top_locations(state.location_requests),
      last_hour_reset: state.last_hour_reset,
      last_day_reset: state.last_day_reset
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:can_scrape, location}, _from, state) do
    can_scrape = 
      state.daily_requests < @daily_request_limit and
      state.hourly_requests < @hourly_request_limit and
      not MapSet.member?(state.blocked_locations, location)

    {:reply, can_scrape, state}
  end

  @impl true
  def handle_info(:hourly_reset, state) do
    Logger.info("🔄 Hourly scraping stats reset. Requests this hour: #{state.hourly_requests}")
    
    new_state = %{
      state
      | hourly_requests: 0,
        last_hour_reset: DateTime.utc_now()
    }
    
    # Schedule next hourly reset
    :timer.send_after(:timer.hours(1), self(), :hourly_reset)
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:daily_cleanup, state) do
    Logger.info("🧹 Daily scraping cleanup. Total requests today: #{state.daily_requests}")
    
    new_state = %{
      state
      | daily_requests: 0,
        location_requests: %{},
        blocked_locations: MapSet.new(),
        last_day_reset: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end

  defp get_top_locations(location_requests) do
    location_requests
    |> Enum.sort_by(fn {_location, count} -> count end, :desc)
    |> Enum.take(10)
  end
end