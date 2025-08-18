defmodule RouteWiseApi.LocationIQ.CircuitBreaker do
  @moduledoc """
  Circuit breaker for LocationIQ API requests.
  
  Implements the circuit breaker pattern to prevent cascading failures
  when LocationIQ API is experiencing issues. Uses a state machine with
  three states: closed, open, and half-open.
  
  States:
  - Closed: Normal operation, tracking failures
  - Open: Blocking requests after failure threshold, return cached results  
  - Half-Open: Testing API recovery with limited requests
  
  Features:
  - Configurable failure threshold and timeout periods
  - Automatic state transitions based on success/failure rates
  - Graceful degradation to cached data during outages
  - Comprehensive error categorization and reporting
  """
  
  use GenServer
  require Logger

  @table_name :location_iq_circuit_breaker
  @check_interval 5000  # Check circuit state every 5 seconds

  # Default circuit breaker configuration
  @default_config %{
    failure_threshold: 5,          # Open after 5 consecutive failures
    recovery_timeout: 30_000,      # Wait 30s before trying half-open
    success_threshold: 3,          # Close after 3 consecutive successes in half-open
    monitor_window: 60_000,        # Monitor failures over 1 minute window
    max_half_open_requests: 3      # Allow max 3 requests in half-open state
  }

  defmodule State do
    @moduledoc false
    defstruct [
      :service,
      :status,                    # :closed, :open, :half_open
      :failure_count,
      :success_count, 
      :last_failure_time,
      :state_changed_at,
      :half_open_requests,
      :config
    ]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a function with circuit breaker protection.

  Returns the result of the function if circuit is closed or half-open,
  or returns an error if circuit is open.

  ## Examples
      iex> call("autocomplete", fn -> LocationIQ.api_call() end, fn -> cached_fallback() end)
      {:ok, result}

      iex> call("autocomplete", fn -> LocationIQ.api_call() end, fn -> cached_fallback() end)
      {:error, :circuit_open, cached_result}
  """
  def call(service, api_function, fallback_function \\ nil) do
    GenServer.call(__MODULE__, {:execute, service, api_function, fallback_function})
  end

  @doc """
  Record a successful API call to update circuit state.
  """
  def record_success(service) do
    GenServer.cast(__MODULE__, {:record_success, service})
  end

  @doc """
  Record a failed API call to update circuit state.
  """
  def record_failure(service, error) do
    GenServer.cast(__MODULE__, {:record_failure, service, error})
  end

  @doc """
  Get current circuit breaker state.

  ## Examples
      iex> get_state("autocomplete")
      %{
        status: :closed,
        failure_count: 0, 
        success_count: 0,
        last_failure_time: nil,
        state_changed_at: ~U[2024-08-06 19:30:00Z]
      }
  """
  def get_state(service) do
    GenServer.call(__MODULE__, {:get_state, service})
  end

  @doc """
  Force circuit state change for testing or emergency situations.
  """
  def force_state(service, new_status) when new_status in [:closed, :open, :half_open] do
    GenServer.call(__MODULE__, {:force_state, service, new_status})
  end

  @doc """
  Reset circuit breaker to initial state.
  """
  def reset(service) do
    GenServer.call(__MODULE__, {:reset, service})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    # Create ETS table for fast state storage
    :ets.new(@table_name, [:set, :public, :named_table])
    
    # Schedule periodic state checks
    :timer.send_interval(@check_interval, :check_states)
    
    config = Keyword.get(opts, :config, @default_config)
    
    {:ok, %{config: config}}
  end

  @impl true
  def handle_call({:execute, service, api_function, fallback_function}, _from, state) do
    circuit_state = get_or_create_state(service, state.config)
    
    case circuit_state.status do
      :closed ->
        execute_with_monitoring(service, api_function, fallback_function, state.config)
      
      :half_open ->
        if circuit_state.half_open_requests < state.config.max_half_open_requests do
          update_half_open_count(service, circuit_state.half_open_requests + 1)
          execute_with_monitoring(service, api_function, fallback_function, state.config)
        else
          # Too many half-open requests, treat as open
          execute_fallback(service, fallback_function, :circuit_half_open_full)
        end
      
      :open ->
        execute_fallback(service, fallback_function, :circuit_open)
    end
    |> then(fn result -> {:reply, result, state} end)
  end

  @impl true  
  def handle_call({:get_state, service}, _from, state) do
    circuit_state = get_or_create_state(service, state.config)
    
    result = %{
      status: circuit_state.status,
      failure_count: circuit_state.failure_count,
      success_count: circuit_state.success_count,
      last_failure_time: circuit_state.last_failure_time,
      state_changed_at: circuit_state.state_changed_at,
      half_open_requests: circuit_state.half_open_requests
    }
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:force_state, service, new_status}, _from, state) do
    circuit_state = get_or_create_state(service, state.config)
    
    updated_state = %{circuit_state |
      status: new_status,
      state_changed_at: DateTime.utc_now(),
      failure_count: 0,
      success_count: 0,
      half_open_requests: 0
    }
    
    :ets.insert(@table_name, {service, updated_state})
    
    Logger.warning("Circuit breaker for #{service} forced to #{new_status}")
    
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:reset, service}, _from, state) do
    new_state = create_initial_state(service, state.config)
    :ets.insert(@table_name, {service, new_state})
    
    Logger.info("Circuit breaker for #{service} reset")
    
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:record_success, service}, state) do
    circuit_state = get_or_create_state(service, state.config)
    
    updated_state = case circuit_state.status do
      :half_open ->
        success_count = circuit_state.success_count + 1
        
        if success_count >= state.config.success_threshold do
          # Close circuit after enough successes
          Logger.info("Circuit breaker for #{service} closing after #{success_count} successes")
          
          %{circuit_state |
            status: :closed,
            success_count: 0,
            failure_count: 0,
            half_open_requests: 0,
            state_changed_at: DateTime.utc_now()
          }
        else
          %{circuit_state | success_count: success_count}
        end
      
      :closed ->
        # Reset failure count on success
        %{circuit_state | failure_count: 0}
      
      :open ->
        # Ignore successes when open (shouldn't happen)
        circuit_state
    end
    
    :ets.insert(@table_name, {service, updated_state})
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_failure, service, error}, state) do
    circuit_state = get_or_create_state(service, state.config)
    
    # Categorize error to determine if it should count as circuit failure
    should_count_failure = should_count_as_failure?(error)
    
    updated_state = if should_count_failure do
      failure_count = circuit_state.failure_count + 1
      now = DateTime.utc_now()
      
      case circuit_state.status do
        :closed when failure_count >= state.config.failure_threshold ->
          # Open circuit after too many failures
          Logger.warning("Circuit breaker for #{service} opening after #{failure_count} failures: #{inspect(error)}")
          
          %{circuit_state |
            status: :open,
            failure_count: failure_count,
            last_failure_time: now,
            state_changed_at: now
          }
        
        :half_open ->
          # Return to open on any failure in half-open
          Logger.warning("Circuit breaker for #{service} returning to open state on failure: #{inspect(error)}")
          
          %{circuit_state |
            status: :open,
            failure_count: failure_count,
            success_count: 0,
            half_open_requests: 0,
            last_failure_time: now,
            state_changed_at: now
          }
        
        _ ->
          # Just increment failure count
          %{circuit_state |
            failure_count: failure_count,
            last_failure_time: now
          }
      end
    else
      # Don't count certain errors (like validation errors) as circuit failures
      circuit_state
    end
    
    :ets.insert(@table_name, {service, updated_state})
    
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_states, state) do
    check_all_circuits(state.config)
    {:noreply, state}
  end

  # Private functions

  defp execute_with_monitoring(service, api_function, fallback_function, _config) do
    try do
      result = api_function.()
      record_success(service)
      result
    rescue
      error ->
        record_failure(service, error)
        execute_fallback(service, fallback_function, {:api_error, error})
    catch
      :exit, reason ->
        record_failure(service, {:exit, reason})
        execute_fallback(service, fallback_function, {:api_exit, reason})
    end
  end

  defp execute_fallback(service, fallback_function, reason) do
    if fallback_function do
      try do
        fallback_result = fallback_function.()
        Logger.info("Circuit breaker for #{service} using fallback due to: #{inspect(reason)}")
        {:error, reason, fallback_result}
      rescue
        fallback_error ->
          Logger.error("Circuit breaker fallback failed for #{service}: #{inspect(fallback_error)}")
          {:error, {:fallback_failed, reason, fallback_error}}
      end
    else
      Logger.warning("Circuit breaker for #{service} rejecting request: #{inspect(reason)}")
      {:error, reason}
    end
  end

  defp get_or_create_state(service, config) do
    case :ets.lookup(@table_name, service) do
      [{^service, state}] -> state
      [] -> create_initial_state(service, config)
    end
  end

  defp create_initial_state(service, config) do
    state = %State{
      service: service,
      status: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      state_changed_at: DateTime.utc_now(),
      half_open_requests: 0,
      config: config
    }
    
    :ets.insert(@table_name, {service, state})
    state
  end

  defp update_half_open_count(service, count) do
    case :ets.lookup(@table_name, service) do
      [{^service, state}] ->
        updated_state = %{state | half_open_requests: count}
        :ets.insert(@table_name, {service, updated_state})
      [] ->
        :ok  # State doesn't exist, ignore
    end
  end

  defp check_all_circuits(config) do
    :ets.tab2list(@table_name)
    |> Enum.each(fn {service, circuit_state} ->
      check_circuit_transition(service, circuit_state, config)
    end)
  end

  defp check_circuit_transition(service, circuit_state, config) do
    now = DateTime.utc_now()
    
    case circuit_state.status do
      :open ->
        # Check if enough time has passed to try half-open
        time_since_open = DateTime.diff(now, circuit_state.state_changed_at, :millisecond)
        
        if time_since_open >= config.recovery_timeout do
          Logger.info("Circuit breaker for #{service} transitioning to half-open")
          
          updated_state = %{circuit_state |
            status: :half_open,
            state_changed_at: now,
            half_open_requests: 0,
            success_count: 0
          }
          
          :ets.insert(@table_name, {service, updated_state})
        end
      
      _ ->
        # No automatic transitions needed for closed or half-open
        :ok
    end
  end

  defp should_count_as_failure?(error) do
    case error do
      # HTTP errors that should trip circuit
      %HTTPoison.Error{reason: :timeout} -> true
      %HTTPoison.Error{reason: :connect_timeout} -> true
      %HTTPoison.Error{reason: :recv_timeout} -> true
      %HTTPoison.Error{reason: :closed} -> true
      %HTTPoison.Error{reason: :econnrefused} -> true
      
      # API errors that should trip circuit  
      "LocationIQ API error: 500" -> true
      "LocationIQ API error: 502" -> true
      "LocationIQ API error: 503" -> true
      "LocationIQ API error: 504" -> true
      
      # Rate limiting shouldn't trip circuit (handled by rate limiter)
      "LocationIQ API error: 429" -> false
      
      # Client errors shouldn't trip circuit
      "LocationIQ API error: 400" -> false
      "LocationIQ API error: 401" -> false
      "LocationIQ API error: 403" -> false
      "LocationIQ API error: 404" -> false
      
      # JSON decode errors should trip circuit (API returning bad data)
      "Invalid response format" -> true
      
      # Default: count as failure for safety
      _ -> true
    end
  end
end