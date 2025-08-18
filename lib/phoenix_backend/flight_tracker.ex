defmodule RouteWiseApi.FlightTracker do
  @moduledoc """
  GenServer for real-time flight tracking and updates.
  
  This GenServer periodically polls the OpenSky Network API to get live aircraft states,
  updates the database cache, and broadcasts updates via Phoenix PubSub.
  
  ## Features
  - Configurable polling intervals (default: 10 seconds)
  - Exponential backoff on API failures
  - Automatic retry with circuit breaker pattern
  - Geographic filtering for performance
  - Database caching with smart updates
  - PubSub broadcasting for real-time updates
  
  ## Configuration
  Configure in config/config.exs:
  ```elixir
  config :phoenix_backend, RouteWiseApi.FlightTracker,
    enabled: true,
    polling_interval: 10_000,  # 10 seconds
    geographic_bounds: {33.7, 34.3, -118.7, -117.9},  # LA area
    max_aircraft: 500,
    retry_backoff_base: 1000,
    max_retry_backoff: 60_000,
    circuit_breaker_threshold: 5
  ```
  """
  
  use GenServer
  require Logger
  
  alias RouteWiseApi.{FlightTrackingService, Repo}
  alias RouteWiseApi.FlightTracking.{LiveAircraftState}
  alias Phoenix.PubSub
  
  @default_config %{
    enabled: true,
    polling_interval: 10_000,           # 10 seconds
    geographic_bounds: nil,             # No geographic filtering by default
    max_aircraft: 1000,                 # Max aircraft to track
    retry_backoff_base: 1000,           # 1 second base backoff
    max_retry_backoff: 60_000,          # 1 minute max backoff
    circuit_breaker_threshold: 5,       # Failures before circuit opens
    pubsub_topic: "flight_tracking"     # PubSub topic for broadcasts
  }
  
  defmodule State do
    @moduledoc false
    defstruct [
      :config,
      :timer_ref,
      failure_count: 0,
      last_success: nil,
      circuit_open: false,
      circuit_open_until: nil,
      last_api_call: nil,
      aircraft_count: 0,
      total_updates: 0,
      api_error_count: 0
    ]
  end
  
  # Client API
  
  @doc """
  Start the FlightTracker GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get current flight tracker statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Force a flight data update (bypasses normal polling interval).
  """
  def force_update do
    GenServer.cast(__MODULE__, :force_update)
  end
  
  @doc """
  Pause flight tracking.
  """
  def pause do
    GenServer.cast(__MODULE__, :pause)
  end
  
  @doc """
  Resume flight tracking.
  """
  def resume do
    GenServer.cast(__MODULE__, :resume)
  end
  
  @doc """
  Update configuration on the fly.
  """
  def update_config(new_config) do
    GenServer.cast(__MODULE__, {:update_config, new_config})
  end
  
  # GenServer callbacks
  
  @impl GenServer
  def init(opts) do
    config = 
      Application.get_env(:phoenix_backend, __MODULE__, %{})
      |> Map.merge(@default_config)
      |> Map.merge(Enum.into(opts, %{}))
    
    if config.enabled do
      Logger.info("FlightTracker starting with polling interval: #{config.polling_interval}ms")
      timer_ref = schedule_next_update(config.polling_interval)
      
      state = %State{
        config: config,
        timer_ref: timer_ref,
        last_success: DateTime.utc_now()
      }
      
      {:ok, state}
    else
      Logger.info("FlightTracker disabled by configuration")
      {:ok, %State{config: config}}
    end
  end
  
  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      enabled: state.config.enabled,
      failure_count: state.failure_count,
      last_success: state.last_success,
      circuit_open: state.circuit_open,
      circuit_open_until: state.circuit_open_until,
      last_api_call: state.last_api_call,
      aircraft_count: state.aircraft_count,
      total_updates: state.total_updates,
      api_error_count: state.api_error_count,
      polling_interval: state.config.polling_interval,
      geographic_bounds: state.config.geographic_bounds
    }
    
    {:reply, stats, state}
  end
  
  @impl GenServer
  def handle_cast(:force_update, state) do
    if state.config.enabled do
      Logger.info("Forcing flight data update")
      new_state = perform_update(state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  def handle_cast(:pause, state) do
    Logger.info("Pausing flight tracking")
    
    new_config = Map.put(state.config, :enabled, false)
    new_state = %{state | config: new_config}
    
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end
    
    {:noreply, %{new_state | timer_ref: nil}}
  end
  
  def handle_cast(:resume, state) do
    Logger.info("Resuming flight tracking")
    
    new_config = Map.put(state.config, :enabled, true)
    timer_ref = schedule_next_update(state.config.polling_interval)
    
    new_state = %{state | config: new_config, timer_ref: timer_ref}
    {:noreply, new_state}
  end
  
  def handle_cast({:update_config, config_updates}, state) do
    Logger.info("Updating flight tracker configuration: #{inspect(config_updates)}")
    
    new_config = Map.merge(state.config, config_updates)
    new_state = %{state | config: new_config}
    
    # Reschedule if polling interval changed
    new_state = if Map.has_key?(config_updates, :polling_interval) and state.timer_ref do
      Process.cancel_timer(state.timer_ref)
      timer_ref = schedule_next_update(new_config.polling_interval)
      %{new_state | timer_ref: timer_ref}
    else
      new_state
    end
    
    {:noreply, new_state}
  end
  
  @impl GenServer
  def handle_info(:update_flights, state) do
    if state.config.enabled do
      new_state = perform_update(state)
      
      # Schedule next update
      timer_ref = schedule_next_update(get_next_interval(new_state))
      new_state = %{new_state | timer_ref: timer_ref}
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  def handle_info(msg, state) do
    Logger.warning("FlightTracker received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  @impl GenServer
  def terminate(reason, state) do
    Logger.info("FlightTracker terminating: #{inspect(reason)}")
    
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end
    
    :ok
  end
  
  # Private functions
  
  defp perform_update(state) do
    Logger.debug("Performing flight data update")
    
    if circuit_breaker_open?(state) do
      Logger.warning("Circuit breaker open, skipping API call")
      state
    else
      start_time = System.monotonic_time(:millisecond)
      
      case fetch_and_update_aircraft_states(state.config) do
        {:ok, aircraft_count} ->
          elapsed = System.monotonic_time(:millisecond) - start_time
          
          Logger.info("Successfully updated #{aircraft_count} aircraft states in #{elapsed}ms")
          
          # Reset failure count and circuit breaker on success
          %{state |
            failure_count: 0,
            circuit_open: false,
            circuit_open_until: nil,
            last_success: DateTime.utc_now(),
            last_api_call: DateTime.utc_now(),
            aircraft_count: aircraft_count,
            total_updates: state.total_updates + 1
          }
        
        {:error, reason} ->
          elapsed = System.monotonic_time(:millisecond) - start_time
          failure_count = state.failure_count + 1
          
          Logger.error("Flight data update failed after #{elapsed}ms: #{inspect(reason)}")
          
          # Open circuit breaker if threshold exceeded
          {circuit_open, circuit_open_until} = 
            if failure_count >= state.config.circuit_breaker_threshold do
              backoff_time = calculate_backoff_time(failure_count, state.config)
              open_until = DateTime.add(DateTime.utc_now(), backoff_time, :millisecond)
              {true, open_until}
            else
              {state.circuit_open, state.circuit_open_until}
            end
          
          %{state |
            failure_count: failure_count,
            circuit_open: circuit_open,
            circuit_open_until: circuit_open_until,
            last_api_call: DateTime.utc_now(),
            api_error_count: state.api_error_count + 1
          }
      end
    end
  end
  
  defp fetch_and_update_aircraft_states(config) do
    # Build API request options
    api_opts = case config.geographic_bounds do
      {min_lat, max_lat, min_lon, max_lon} ->
        [bbox: {min_lat, max_lat, min_lon, max_lon}]
      nil ->
        []
    end
    
    case FlightTrackingService.get_live_states(api_opts) do
      {:ok, %{time: _timestamp, states: states}} ->
        # Limit aircraft count if configured
        limited_states = case config.max_aircraft do
          nil -> states
          max when length(states) > max -> Enum.take(states, max)
          _ -> states
        end
        
        # Update database cache
        updated_count = update_aircraft_cache(limited_states)
        
        # Broadcast updates via PubSub
        broadcast_flight_updates(limited_states, config.pubsub_topic)
        
        {:ok, updated_count}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp update_aircraft_cache(states) do
    now = DateTime.utc_now()
    
    # Convert API states to database records
    aircraft_records = Enum.map(states, fn state ->
      %{
        icao24: state.icao24,
        callsign: state.callsign,
        origin_country: state.origin_country,
        time_position: (if state.time_position, do: DateTime.from_unix!(state.time_position)),
        last_contact: DateTime.from_unix!(state.last_contact),
        latitude: state.latitude,
        longitude: state.longitude,
        baro_altitude: state.baro_altitude,
        on_ground: state.on_ground || false,
        velocity: state.velocity,
        true_track: state.true_track,
        vertical_rate: state.vertical_rate,
        geo_altitude: state.geo_altitude,
        squawk: state.squawk,
        spi: state.spi,
        position_source: state.position_source,
        data_source: "opensky",
        last_updated: now,
        inserted_at: now,
        updated_at: now
      }
    end)
    
    # Batch upsert aircraft states
    case Repo.insert_all(
      LiveAircraftState,
      aircraft_records,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:icao24]
    ) do
      {count, _} -> 
        Logger.debug("Updated #{count} aircraft states in database")
        count
        
      _ -> 
        Logger.warning("Failed to update aircraft states in database")
        0
    end
  end
  
  defp broadcast_flight_updates(states, topic) do
    try do
      # Broadcast summary update
      PubSub.broadcast(RouteWiseApi.PubSub, topic, {
        :flight_update, 
        %{
          aircraft_count: length(states),
          timestamp: DateTime.utc_now(),
          states: states
        }
      })
      
      # Broadcast individual aircraft updates for subscribed aircraft
      Enum.each(states, fn state ->
        PubSub.broadcast(RouteWiseApi.PubSub, "#{topic}:#{state.icao24}", {
          :aircraft_update,
          state
        })
      end)
      
    rescue
      error ->
        Logger.error("Failed to broadcast flight updates: #{inspect(error)}")
    end
  end
  
  defp circuit_breaker_open?(state) do
    state.circuit_open and 
      state.circuit_open_until and
      DateTime.compare(DateTime.utc_now(), state.circuit_open_until) == :lt
  end
  
  defp calculate_backoff_time(failure_count, config) do
    backoff = config.retry_backoff_base * :math.pow(2, failure_count - 1)
    min(trunc(backoff), config.max_retry_backoff)
  end
  
  defp get_next_interval(state) do
    if state.failure_count > 0 do
      # Use exponential backoff on failures
      calculate_backoff_time(state.failure_count, state.config)
    else
      # Use normal polling interval on success
      state.config.polling_interval
    end
  end
  
  defp schedule_next_update(interval) do
    Process.send_after(self(), :update_flights, interval)
  end
end