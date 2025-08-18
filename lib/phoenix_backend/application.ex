defmodule RouteWiseApi.Application do
  @moduledoc """
  The RouteWise API application module.

  Defines the OTP application supervision tree for the Phoenix backend,
  including database connections, caching, HTTP clients, and the web endpoint.

  ## Supervision Tree

  The application starts the following supervised processes:

  - **Telemetry**: Application metrics and monitoring
  - **Repo**: Ecto database connection pool
  - **DNSCluster**: DNS-based service discovery (configurable)
  - **PubSub**: Phoenix PubSub for real-time features
  - **Finch**: HTTP client for external API calls
  - **Cache**: In-memory cache GenServer for API response caching
  - **POI ClusteringServer**: Real-time POI clustering with ETS backing
  - **Endpoint**: Phoenix web server and request handling

  ## Configuration

  Key application settings:
  - Database connection via `RouteWiseApi.Repo`
  - DNS cluster query for distributed systems
  - Cache service for Google APIs integration
  - HTTP client pool for external service calls

  ## Restart Strategy

  Uses `:one_for_one` strategy - individual child failures don't affect
  other processes. Critical for API reliability.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RouteWiseApiWeb.Telemetry,
      RouteWiseApi.Repo,
      {DNSCluster, query: Application.get_env(:phoenix_backend, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RouteWiseApi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: RouteWiseApi.Finch},
      # Start the cache service for Express.js integration
      RouteWiseApi.Cache,
      # Start Redis connection for distributed caching
      redis_child_spec(),
      # Start LocationIQ protection services
      {RouteWiseApi.LocationIQ.RateLimiter, get_rate_limiter_config()},
      {RouteWiseApi.LocationIQ.CircuitBreaker, get_circuit_breaker_config()},
      # Start Google API usage tracker
      RouteWiseApi.GoogleAPITracker,
      # Start POI clustering server for real-time map performance
      RouteWiseApi.POI.ClusteringServer,
      # Background scraper for real-time place data collection
      RouteWiseApi.BackgroundScraper,
      # Task supervisor for background scraping processes
      {Task.Supervisor, name: RouteWiseApi.TaskSupervisor},
      # OSM tile caching system
      RouteWiseApi.TileCache,
      RouteWiseApi.OSMTileClient.RateLimiter,
      # Flight tracking GenServer disabled - long-term project
      # RouteWiseApi.FlightTracker,
      # Start a worker by calling: RouteWiseApi.Worker.start_link(arg)
      # {RouteWiseApi.Worker, arg},
      # Start to serve requests, typically the last entry
      RouteWiseApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RouteWiseApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RouteWiseApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Configuration helpers for LocationIQ protection services

  defp get_rate_limiter_config do
    env = Application.get_env(:phoenix_backend, :env, :dev)
    
    base_limits = case env do
      :dev ->
        # Relaxed limits for development
        %{
          requests_per_second: 5,
          requests_per_minute: 100,
          requests_per_hour: 2000,
          requests_per_day: 10000
        }
      
      :test ->
        # Very relaxed for testing
        %{
          requests_per_second: 10,
          requests_per_minute: 500,
          requests_per_hour: 5000,
          requests_per_day: 20000
        }
      
      :prod ->
        # Conservative production limits
        %{
          requests_per_second: 2,
          requests_per_minute: 60,
          requests_per_hour: 1000,
          requests_per_day: 5000
        }
    end
    
    # Allow override via application config
    custom_limits = Application.get_env(:phoenix_backend, :location_iq_rate_limits, %{})
    limits = Map.merge(base_limits, custom_limits)
    
    [limits: limits]
  end

  defp get_circuit_breaker_config do
    env = Application.get_env(:phoenix_backend, :env, :dev)
    
    base_config = case env do
      :dev ->
        # Relaxed for development
        %{
          failure_threshold: 3,
          recovery_timeout: 15_000,
          success_threshold: 2,
          monitor_window: 30_000,
          max_half_open_requests: 5
        }
      
      :test ->
        # Fast recovery for testing
        %{
          failure_threshold: 2,
          recovery_timeout: 5_000,
          success_threshold: 1,
          monitor_window: 10_000,
          max_half_open_requests: 10
        }
      
      :prod ->
        # Conservative production settings
        %{
          failure_threshold: 5,
          recovery_timeout: 30_000,
          success_threshold: 3,
          monitor_window: 60_000,
          max_half_open_requests: 3
        }
    end
    
    # Allow override via application config
    custom_config = Application.get_env(:phoenix_backend, :location_iq_circuit_breaker, %{})
    config = Map.merge(base_config, custom_config)
    
    [config: config]
  end

  # Redis connection for distributed caching
  defp redis_child_spec do
    # Only start Redis in production or if explicitly enabled
    case should_start_redis?() do
      true ->
        {RouteWiseApi.Caching.Backend.Redis, []}
      false ->
        # Return a dummy child spec that won't start anything
        %{
          id: :redis_disabled,
          start: {GenServer, :start_link, [__MODULE__.NoOp, [], [name: :redis_disabled]]},
          restart: :transient
        }
    end
  end

  defp should_start_redis? do
    # Check if Redis is explicitly enabled via environment
    case System.get_env("REDIS_ENABLED") do
      "true" -> true
      "false" -> false
      nil ->
        # Default behavior: enable in production, disable in dev/test
        Mix.env() == :prod
    end
  end

  # No-op GenServer for when Redis is disabled
  defmodule NoOp do
    use GenServer
    
    def init(_), do: {:ok, %{}}
    def handle_call(_, _, state), do: {:reply, :ok, state}
    def handle_cast(_, state), do: {:noreply, state}
    def handle_info(_, state), do: {:noreply, state}
  end
end
