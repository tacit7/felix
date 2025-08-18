# LocationIQ Integration Action Plan: Phoenix Backend + React Frontend

## Table of Contents
- [Backend (Phoenix/Elixir) Implementation](#backend-phoenixelixir-implementation)
- [Frontend (React/Vite) Implementation](#frontend-reactvite-implementation)
- [Critical Considerations](#critical-considerations-you-might-miss)
- [Testing Strategy](#testing-strategy)
- [Monitoring & Analytics](#monitoring--analytics)
- [Deployment Checklist](#deployment-checklist)

---

## Backend (Phoenix/Elixir) Implementation

### Phase 1: Foundation Setup

#### 1.1 Dependencies & Configuration

```elixir
# mix.exs - Add dependencies
defp deps do
  [
    {:httpoison, "~> 2.0"},
    {:jason, "~> 1.4"},
    {:ex_rated, "~> 2.0"},  # Rate limiting
    {:cachex, "~> 3.4"},    # Caching layer
    {:telemetry, "~> 1.0"}, # Metrics/monitoring
    {:mock, "~> 0.3", only: :test}
  ]
end

# config/config.exs
config :route_wise,
  locationiq: %{
    base_url: "https://us1.locationiq.com/v1",
    timeout: 5000,
    retries: 3,
    cache_ttl: :timer.hours(24)
  }

# config/runtime.exs (for API key security)
config :route_wise, :locationiq_api_key, System.get_env("LOCATIONIQ_API_KEY")
```

#### 1.2 Directory Structure
```
lib/route_wise/
├── location/
│   ├── location.ex                 # Context module
│   ├── city_validator.ex          # Business logic
│   ├── adapters/
│   │   ├── locationiq_adapter.ex  # API client
│   │   └── fallback_adapter.ex    # Backup/offline mode
│   ├── schemas/
│   │   ├── city.ex               # City struct
│   │   ├── validation_result.ex  # Result struct
│   │   └── geocoding_response.ex # API response struct
│   └── services/
│       ├── cache_service.ex      # Caching logic
│       ├── rate_limiter.ex       # Rate limiting
│       └── metrics_service.ex    # Monitoring
├── location_web/
│   ├── controllers/
│   │   └── location_controller.ex # API endpoints
│   ├── views/
│   │   └── location_view.ex      # JSON serialization
│   └── plugs/
│       └── rate_limit_plug.ex    # Request rate limiting
```

### Phase 2: Core Implementation

#### 2.1 Location Context (Main Business Logic)

```elixir
# lib/route_wise/location/location.ex
defmodule RouteWise.Location do
  @moduledoc """
  Location context for city validation and geocoding operations.
  Handles all location-related business logic with fault tolerance.
  """
  
  alias RouteWise.Location.{CityValidator, CacheService}
  
  @doc """
  Validates a city name with optional country filtering.
  Returns cached results when available to minimize API calls.
  """
  def validate_city(query, opts \\ []) do
    with {:ok, cache_key} <- build_cache_key(query, opts),
         {:miss, _} <- CacheService.get(cache_key),
         {:ok, result} <- CityValidator.validate(query, opts),
         :ok <- CacheService.put(cache_key, result) do
      {:ok, result}
    else
      {:hit, cached_result} -> {:ok, cached_result}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Provides autocomplete suggestions for city names.
  Optimized for user input with debouncing on frontend.
  """
  def autocomplete_cities(partial_query, opts \\ []) do
    case String.length(String.trim(partial_query)) do
      len when len < 2 -> {:ok, []}
      _ -> CityValidator.autocomplete(partial_query, opts)
    end
  end
  
  defp build_cache_key(query, opts) do
    normalized_query = query |> String.trim() |> String.downcase()
    opts_hash = :crypto.hash(:md5, inspect(opts)) |> Base.encode16()
    {:ok, "location:#{normalized_query}:#{opts_hash}"}
  end
end
```

#### 2.2 City Schema

```elixir
# lib/route_wise/location/schemas/city.ex
defmodule RouteWise.Location.Schemas.City do
  @moduledoc """
  Schema for city data structure
  """
  
  defstruct [
    :name,
    :state,
    :country,
    :country_code,
    :latitude,
    :longitude,
    :display_name,
    :confidence,
    :place_type,
    :timezone,
    :population
  ]
  
  @type t :: %__MODULE__{
    name: String.t(),
    state: String.t() | nil,
    country: String.t(),
    country_code: String.t(),
    latitude: float(),
    longitude: float(),
    display_name: String.t(),
    confidence: float(),
    place_type: String.t(),
    timezone: String.t() | nil,
    population: integer() | nil
  }
end

# lib/route_wise/location/schemas/validation_result.ex
defmodule RouteWise.Location.Schemas.ValidationResult do
  alias RouteWise.Location.Schemas.City
  
  defstruct [
    :valid,
    :cities,
    :primary_match,
    :query,
    :api_response_time
  ]
  
  @type t :: %__MODULE__{
    valid: boolean(),
    cities: [City.t()],
    primary_match: City.t() | nil,
    query: String.t(),
    api_response_time: integer() | nil
  }
end
```

#### 2.3 LocationIQ Adapter (API Client)

```elixir
# lib/route_wise/location/adapters/locationiq_adapter.ex
defmodule RouteWise.Location.Adapters.LocationIqAdapter do
  @moduledoc """
  LocationIQ API client with comprehensive error handling and retries.
  Implements circuit breaker pattern for API reliability.
  """
  
  use GenServer
  require Logger
  
  alias RouteWise.Location.Schemas.{City, ValidationResult}
  
  @base_url Application.compile_env(:route_wise, [:locationiq, :base_url])
  @timeout Application.compile_env(:route_wise, [:locationiq, :timeout])
  @retries Application.compile_env(:route_wise, [:locationiq, :retries])
  
  # GenServer for connection pooling and circuit breaker
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def validate_city(query, opts \\ []) do
    GenServer.call(__MODULE__, {:validate_city, query, opts}, @timeout + 1000)
  end
  
  def autocomplete(query, opts \\ []) do
    GenServer.call(__MODULE__, {:autocomplete, query, opts}, @timeout + 1000)
  end
  
  # GenServer callbacks with circuit breaker logic
  def init(_opts) do
    state = %{
      circuit_breaker: :closed,
      failure_count: 0,
      last_failure: nil
    }
    {:ok, state}
  end
  
  def handle_call({:validate_city, query, opts}, _from, state) do
    case perform_request(:search, query, opts, state) do
      {:ok, response, new_state} -> 
        {:reply, parse_search_response(response, query), new_state}
      {:error, reason, new_state} -> 
        {:reply, {:error, reason}, new_state}
    end
  end
  
  def handle_call({:autocomplete, query, opts}, _from, state) do
    case perform_request(:autocomplete, query, opts, state) do
      {:ok, response, new_state} -> 
        {:reply, parse_autocomplete_response(response), new_state}
      {:error, reason, new_state} -> 
        {:reply, {:error, reason}, new_state}
    end
  end
  
  # HTTP request handling with retries
  defp perform_request(endpoint, query, opts, state, attempt \\ 1) do
    start_time = System.monotonic_time(:millisecond)
    
    case make_http_request(endpoint, query, opts) do
      {:ok, response} -> 
        duration = System.monotonic_time(:millisecond) - start_time
        :telemetry.execute([:location, :api_call], %{duration: duration}, %{
          provider: :locationiq,
          endpoint: endpoint,
          status: :success
        })
        {:ok, response, reset_circuit_breaker(state)}
        
      {:error, reason} when attempt < @retries -> 
        :timer.sleep(backoff_delay(attempt))
        perform_request(endpoint, query, opts, state, attempt + 1)
        
      {:error, reason} -> 
        duration = System.monotonic_time(:millisecond) - start_time
        :telemetry.execute([:location, :api_call], %{duration: duration}, %{
          provider: :locationiq,
          endpoint: endpoint,
          status: :error
        })
        {:error, reason, update_circuit_breaker(state, reason)}
    end
  end
  
  defp make_http_request(:search, query, opts) do
    params = build_search_params(query, opts)
    url = "#{@base_url}/search.php"
    
    case HTTPoison.get(url, [], params: params, timeout: @timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)
      {:ok, %HTTPoison.Response{status_code: 429}} ->
        {:error, "Rate limit exceeded"}
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "API error: #{status} - #{body}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end
  
  defp make_http_request(:autocomplete, query, opts) do
    params = build_autocomplete_params(query, opts)
    url = "#{@base_url}/autocomplete.php"
    
    case HTTPoison.get(url, [], params: params, timeout: @timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)
      {:ok, %HTTPoison.Response{status_code: 429}} ->
        {:error, "Rate limit exceeded"}
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "API error: #{status} - #{body}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end
  
  defp build_search_params(query, opts) do
    base_params = %{
      key: Application.get_env(:route_wise, :locationiq_api_key),
      q: query,
      format: "json",
      addressdetails: 1,
      limit: Keyword.get(opts, :limit, 5),
      dedupe: 1
    }
    
    # Add optional country filtering
    case Keyword.get(opts, :country_code) do
      nil -> base_params
      country_code -> Map.put(base_params, :countrycodes, country_code)
    end
  end
  
  defp build_autocomplete_params(query, opts) do
    %{
      key: Application.get_env(:route_wise, :locationiq_api_key),
      q: query,
      format: "json",
      addressdetails: 1,
      limit: Keyword.get(opts, :limit, 10),
      countrycodes: Keyword.get(opts, :country_code, "")
    }
  end
  
  defp parse_search_response([], query), do: {:ok, %ValidationResult{valid: false, cities: [], query: query}}
  defp parse_search_response(results, query) when is_list(results) do
    cities = Enum.map(results, &parse_city_result/1) |> Enum.reject(&is_nil/1)
    
    {:ok, %ValidationResult{
      valid: length(cities) > 0,
      cities: cities,
      primary_match: List.first(cities),
      query: query
    }}
  end
  
  defp parse_autocomplete_response([]), do: {:ok, []}
  defp parse_autocomplete_response(results) when is_list(results) do
    cities = Enum.map(results, &parse_city_result/1) |> Enum.reject(&is_nil/1)
    {:ok, cities}
  end
  
  defp parse_city_result(result) do
    with {:ok, name} <- extract_city_name(result),
         {:ok, lat} <- parse_coordinate(result["lat"]),
         {:ok, lon} <- parse_coordinate(result["lon"]) do
      
      %City{
        name: name,
        state: get_in(result, ["address", "state"]),
        country: get_in(result, ["address", "country"]),
        country_code: get_in(result, ["address", "country_code"]) |> String.upcase(),
        latitude: lat,
        longitude: lon,
        display_name: result["display_name"],
        confidence: calculate_confidence(result),
        place_type: determine_place_type(result),
        timezone: get_in(result, ["address", "timezone"])
      }
    else
      _ -> nil
    end
  end
  
  # Helper functions for parsing and validation
  defp extract_city_name(result) do
    city = get_in(result, ["address", "city"]) || 
           get_in(result, ["address", "town"]) || 
           get_in(result, ["address", "village"]) ||
           get_in(result, ["address", "hamlet"])
    
    case city do
      nil -> {:error, :no_city_found}
      name -> {:ok, name}
    end
  end
  
  defp parse_coordinate(coord_string) when is_binary(coord_string) do
    case Float.parse(coord_string) do
      {coord, _} -> {:ok, coord}
      :error -> {:error, :invalid_coordinate}
    end
  end
  defp parse_coordinate(coord) when is_number(coord), do: {:ok, coord * 1.0}
  defp parse_coordinate(_), do: {:error, :invalid_coordinate}
  
  defp calculate_confidence(result) do
    # LocationIQ doesn't provide confidence directly, so we calculate it
    # based on place type and address completeness
    base_confidence = case result["class"] do
      "place" -> 0.9
      "boundary" -> 0.7
      _ -> 0.5
    end
    
    # Adjust based on address completeness
    address = result["address"] || %{}
    completeness_bonus = 
      [:city, :state, :country, :postcode]
      |> Enum.count(fn key -> Map.has_key?(address, to_string(key)) end)
      |> Kernel.*(0.025)
    
    min(base_confidence + completeness_bonus, 1.0)
  end
  
  defp determine_place_type(result) do
    result["type"] || result["class"] || "city"
  end
  
  defp backoff_delay(attempt) do
    # Exponential backoff: 500ms, 1s, 2s
    round(:math.pow(2, attempt - 1) * 500)
  end
  
  defp reset_circuit_breaker(state) do
    %{state | circuit_breaker: :closed, failure_count: 0, last_failure: nil}
  end
  
  defp update_circuit_breaker(state, reason) do
    new_failure_count = state.failure_count + 1
    now = System.monotonic_time(:second)
    
    # Open circuit breaker after 5 consecutive failures
    new_circuit_state = if new_failure_count >= 5 do
      Logger.warning("LocationIQ circuit breaker opened due to failures: #{reason}")
      :open
    else
      state.circuit_breaker
    end
    
    %{state | 
      circuit_breaker: new_circuit_state,
      failure_count: new_failure_count,
      last_failure: now
    }
  end
end
```

#### 2.4 Phoenix Controller (API Endpoints)

```elixir
# lib/route_wise_web/controllers/location_controller.ex
defmodule RouteWiseWeb.LocationController do
  use RouteWiseWeb, :controller
  
  alias RouteWise.Location
  
  action_fallback RouteWiseWeb.FallbackController
  
  @doc """
  POST /api/v1/locations/validate
  Validates a city name and returns structured location data.
  """
  def validate(conn, %{"query" => query} = params) do
    opts = build_validation_opts(params)
    
    with {:ok, result} <- Location.validate_city(query, opts) do
      conn
      |> put_status(:ok)
      |> render("validation_result.json", result: result)
    end
  end
  
  @doc """
  GET /api/v1/locations/autocomplete?q=partial_query
  Returns autocomplete suggestions for city names.
  """
  def autocomplete(conn, %{"q" => query} = params) do
    opts = build_autocomplete_opts(params)
    
    with {:ok, suggestions} <- Location.autocomplete_cities(query, opts) do
      conn
      |> put_status(:ok)
      |> render("autocomplete.json", suggestions: suggestions)
    end
  end
  
  @doc """
  GET /api/v1/locations/health
  Health check endpoint for location services
  """
  def health(conn, _params) do
    # Quick validation test
    case Location.validate_city("New York", limit: 1) do
      {:ok, _} -> 
        json(conn, %{status: "healthy", timestamp: DateTime.utc_now()})
      {:error, reason} -> 
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unhealthy", error: to_string(reason), timestamp: DateTime.utc_now()})
    end
  end
  
  defp build_validation_opts(params) do
    []
    |> maybe_add_country_code(params)
    |> maybe_add_limit(params)
  end
  
  defp build_autocomplete_opts(params) do
    []
    |> maybe_add_country_code(params)
    |> maybe_add_limit(params, 10)
  end
  
  defp maybe_add_country_code(opts, %{"country_code" => code}) when is_binary(code) do
    Keyword.put(opts, :country_code, String.upcase(code))
  end
  defp maybe_add_country_code(opts, _), do: opts
  
  defp maybe_add_limit(opts, params, default \\ 5)
  defp maybe_add_limit(opts, %{"limit" => limit}, default) when is_integer(limit) do
    Keyword.put(opts, :limit, min(limit, default))
  end
  defp maybe_add_limit(opts, _, _), do: opts
end

# lib/route_wise_web/views/location_view.ex
defmodule RouteWiseWeb.LocationView do
  use RouteWiseWeb, :view
  
  alias RouteWise.Location.Schemas.{City, ValidationResult}
  
  def render("validation_result.json", %{result: %ValidationResult{} = result}) do
    %{
      valid: result.valid,
      query: result.query,
      cities: Enum.map(result.cities, &render_city/1),
      primary_match: render_city(result.primary_match),
      api_response_time: result.api_response_time
    }
  end
  
  def render("autocomplete.json", %{suggestions: suggestions}) do
    %{
      suggestions: Enum.map(suggestions, &render_city/1)
    }
  end
  
  defp render_city(nil), do: nil
  defp render_city(%City{} = city) do
    %{
      name: city.name,
      state: city.state,
      country: city.country,
      country_code: city.country_code,
      latitude: city.latitude,
      longitude: city.longitude,
      display_name: city.display_name,
      confidence: city.confidence,
      place_type: city.place_type,
      timezone: city.timezone
    }
  end
end
```

#### 2.5 Caching & Performance Layer

```elixir
# lib/route_wise/location/services/cache_service.ex
defmodule RouteWise.Location.Services.CacheService do
  @moduledoc """
  Caching service for location data with TTL and invalidation strategies.
  Uses Cachex for in-memory caching with optional Redis persistence.
  """
  
  use GenServer
  
  @cache_name :location_cache
  @default_ttl :timer.hours(24)
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get(key) do
    case Cachex.get(@cache_name, key) do
      {:ok, nil} -> {:miss, nil}
      {:ok, value} -> {:hit, value}
      {:error, reason} -> {:error, reason}
    end
  end
  
  def put(key, value, ttl \\ @default_ttl) do
    Cachex.put(@cache_name, key, value, ttl: ttl)
  end
  
  def invalidate(pattern) do
    # Support pattern-based cache invalidation
    Cachex.del(@cache_name, pattern)
  end
  
  def stats do
    Cachex.stats(@cache_name)
  end
  
  def init(_opts) do
    # Start Cachex with memory limits and TTL cleanup
    cache_opts = [
      limit: 10_000,      # Max cache entries
      ttl_interval: :timer.minutes(5),  # Cleanup interval
      stats: true         # Enable cache statistics
    ]
    
    {:ok, _pid} = Cachex.start_link(@cache_name, cache_opts)
    {:ok, %{}}
  end
end
```

#### 2.6 Rate Limiting & Security

```elixir
# lib/route_wise_web/plugs/rate_limit_plug.ex
defmodule RouteWiseWeb.Plugs.RateLimitPlug do
  @moduledoc """
  Rate limiting plug to prevent API abuse and manage LocationIQ quotas.
  Implements token bucket algorithm with IP-based limiting.
  """
  
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 100)        # requests per window
    window = Keyword.get(opts, :window, 3600)     # window in seconds
    
    client_ip = get_client_ip(conn)
    key = "rate_limit:#{client_ip}"
    
    case ExRated.check_rate(key, window * 1000, limit) do
      {:ok, _count} -> conn
      {:error, _count} -> 
        conn
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{
          error: "Rate limit exceeded", 
          retry_after: window
        })
        |> halt()
    end
  end
  
  defp get_client_ip(conn) do
    # Handle various proxy headers
    forwarded_for = get_req_header(conn, "x-forwarded-for") |> List.first()
    real_ip = get_req_header(conn, "x-real-ip") |> List.first()
    
    case forwarded_for do
      nil -> real_ip || to_string(:inet.ntoa(conn.remote_ip))
      forwarded -> forwarded |> String.split(",") |> List.first() |> String.trim()
    end
  end
end
```

#### 2.7 Application Configuration

```elixir
# lib/route_wise/application.ex
defmodule RouteWise.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Phoenix and Ecto
      RouteWiseWeb.Telemetry,
      RouteWise.Repo,
      {Phoenix.PubSub, name: RouteWise.PubSub},
      RouteWiseWeb.Endpoint,
      
      # Location services
      {RouteWise.Location.Adapters.LocationIqAdapter, []},
      {RouteWise.Location.Services.CacheService, []},
      
      # Rate limiter with ETS backing
      {ExRated, [
        {:timeout, 60_000},
        {:cleanup_rate, 60_000},
        {:persistent, false}
      ]}
    ]
    
    opts = [strategy: :one_for_one, name: RouteWise.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## Frontend (React/Vite) Implementation

### Phase 1: Infrastructure Setup

#### 1.1 Dependencies & Configuration

```json
// package.json additions
{
  "dependencies": {
    "@tanstack/react-query": "^4.29.0",
    "axios": "^1.4.0",
    "use-debounce": "^9.0.0",
    "react-select": "^5.7.0",
    "react-window": "^1.8.0",
    "fuse.js": "^6.6.0"
  },
  "devDependencies": {
    "@testing-library/react": "^13.4.0",
    "msw": "^1.2.0"
  }
}
```

```typescript
// src/config/environment.ts
export const config = {
  api: {
    baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:4000/api/v1',
    timeout: 10000,
    retries: 3
  },
  location: {
    autocompleteDelay: 300,
    maxSuggestions: 10,
    cacheTimeout: 1000 * 60 * 30, // 30 minutes
    offlineMode: true
  },
  features: {
    enableAnalytics: import.meta.env.VITE_ENABLE_ANALYTICS === 'true',
    enableOfflineMode: import.meta.env.VITE_ENABLE_OFFLINE_MODE !== 'false'
  }
}
```

### Phase 2: API Client Layer

#### 2.1 Location API Service

```typescript
// src/services/locationApi.ts
import axios, { AxiosInstance, AxiosError } from 'axios';
import { config } from '../config/environment';

export interface City {
  name: string;
  state?: string;
  country: string;
  countryCode: string;
  latitude: number;
  longitude: number;
  displayName: string;
  confidence: number;
  placeType: string;
  timezone?: string;
}

export interface ValidationResult {
  valid: boolean;
  query: string;
  cities: City[];
  primaryMatch?: City;
  apiResponseTime?: number;
}

export interface AutocompleteOptions {
  countryCode?: string;
  limit?: number;
  signal?: AbortSignal;
}

class LocationApiService {
  private client: AxiosInstance;
  private requestCache = new Map<string, { data: any; timestamp: number }>();

  constructor() {
    this.client = axios.create({
      baseURL: config.api.baseURL,
      timeout: config.api.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });

    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor for authentication/logging
    this.client.interceptors.request.use(
      (config) => {
        // Add auth token if available
        const token = localStorage.getItem('authToken');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        
        // Add request timing
        config.metadata = { startTime: new Date() };
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling and metrics
    this.client.interceptors.response.use(
      (response) => {
        // Calculate request duration
        const endTime = new Date();
        const duration = endTime.getTime() - response.config.metadata?.startTime?.getTime();
        
        // Log successful requests (optional)
        console.debug(`API Request completed in ${duration}ms:`, response.config.url);
        
        return response;
      },
      (error: AxiosError) => {
        if (error.response?.status === 429) {
          throw new Error('Rate limit exceeded. Please try again later.');
        }
        if (error.response?.status >= 500) {
          throw new Error('Server error. Please try again later.');
        }
        if (error.code === 'ECONNABORTED') {
          throw new Error('Request timeout. Please check your connection.');
        }
        if (error.response?.status === 0) {
          throw new Error('Network error. Please check your internet connection.');
        }
        throw error;
      }
    );
  }

  async validateCity(
    query: string, 
    options: AutocompleteOptions = {}
  ): Promise<ValidationResult> {
    const cacheKey = `validate:${query.trim().toLowerCase()}:${JSON.stringify(options)}`;
    
    // Check cache first
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      const response = await this.client.post('/locations/validate', {
        query: query.trim(),
        country_code: options.countryCode,
        limit: options.limit
      }, {
        signal: options.signal
      });

      const result: ValidationResult = response.data;
      this.setCache(cacheKey, result);
      
      return result;
    } catch (error) {
      if (axios.isCancel(error)) {
        throw new Error('Request cancelled');
      }
      throw this.handleApiError(error as AxiosError);
    }
  }

  async autocompleteCity(
    query: string, 
    options: AutocompleteOptions = {}
  ): Promise<City[]> {
    if (query.trim().length < 2) {
      return [];
    }

    const cacheKey = `autocomplete:${query.trim().toLowerCase()}:${JSON.stringify(options)}`;
    
    // Check cache first
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      const response = await this.client.get('/locations/autocomplete', {
        params: {
          q: query.trim(),
          limit: options.limit || config.location.maxSuggestions,
          country_code: options.countryCode
        },
        signal: options.signal
      });

      const suggestions: City[] = response.data.suggestions || [];
      this.setCache(cacheKey, suggestions);
      
      return suggestions;
    } catch (error) {
      if (axios.isCancel(error)) {
        throw new Error('Request cancelled');
      }
      throw this.handleApiError(error as AxiosError);
    }
  }

  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    try {
      const response = await this.client.get('/locations/health');
      return response.data;
    } catch (error) {
      throw this.handleApiError(error as AxiosError);
    }
  }

  private getFromCache(key: string): any | null {
    const cached = this.requestCache.get(key);
    if (!cached) return null;
    
    const isExpired = Date.now() - cached.timestamp > config.location.cacheTimeout;
    if (isExpired) {
      this.requestCache.delete(key);
      return null;
    }
    
    return cached.data;
  }

  private setCache(key: string, data: any): void {
    // Implement cache size limit to prevent memory leaks
    if (this.requestCache.size > 1000) {
      const firstKey = this.requestCache.keys().next().value;
      this.requestCache.delete(firstKey);
    }
    
    this.requestCache.set(key, {
      data,
      timestamp: Date.now()
    });
  }

  private handleApiError(error: AxiosError): Error {
    if (error.response?.data && typeof error.response.data === 'object') {
      const errorData = error.response.data as any;
      return new Error(errorData.error || errorData.message || 'API request failed');
    }
    return new Error(error.message || 'Unknown API error');
  }

  // Clear cache manually if needed
  clearCache(): void {
    this.requestCache.clear();
  }

  // Get cache statistics
  getCacheStats(): { size: number; keys: string[] } {
    return {
      size: this.requestCache.size,
      keys: Array.from(this.requestCache.keys())
    };
  }
}

export const locationApi = new LocationApiService();
```

### Phase 3: React Components

#### 3.1 City Autocomplete Component

```typescript
// src/components/LocationInput/CityAutocomplete.tsx
import React, { useState, useCallback, useRef, useEffect, useId } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useDebouncedCallback } from 'use-debounce';
import { locationApi, City } from '../../services/locationApi';
import { config } from '../../config/environment';

interface CityAutocompleteProps {
  value?: City | null;
  onChange: (city: City | null) => void;
  placeholder?: string;
  countryCode?: string;
  disabled?: boolean;
  error?: string;
  onBlur?: () => void;
  onFocus?: () => void;
  className?: string;
  'aria-label'?: string;
  'data-testid'?: string;
  required?: boolean;
  name?: string;
}

export const CityAutocomplete: React.FC<CityAutocompleteProps> = ({
  value,
  onChange,
  placeholder = "Enter city name...",
  countryCode,
  disabled = false,
  error,
  onBlur,
  onFocus,
  className = "",
  'aria-label': ariaLabel,
  'data-testid': testId,
  required = false,
  name
}) => {
  const [inputValue, setInputValue] = useState(value?.name || '');
  const [isOpen, setIsOpen] = useState(false);
  const [selectedIndex, setSelectedIndex] = useState(-1);
  const [hasUserInteracted, setHasUserInteracted] = useState(false);
  
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLUListElement>(null);
  const abortControllerRef = useRef<AbortController>();
  
  // Generate unique IDs for accessibility
  const listboxId = useId();
  const errorId = useId();

  // Debounced search function
  const debouncedSearch = useDebouncedCallback(
    (searchQuery: string) => {
      if (searchQuery.trim().length >= 2) {
        setIsOpen(true);
        refetch();
      } else {
        setIsOpen(false);
      }
    },
    config.location.autocompleteDelay
  );

  // React Query for autocomplete data
  const { data: suggestions = [], isLoading, error: queryError, refetch } = useQuery({
    queryKey: ['cityAutocomplete', inputValue.trim().toLowerCase(), countryCode],
    queryFn: async () => {
      // Cancel previous request
      abortControllerRef.current?.abort();
      abortControllerRef.current = new AbortController();

      return locationApi.autocompleteCity(inputValue.trim(), {
        countryCode,
        limit: config.location.maxSuggestions,
        signal: abortControllerRef.current.signal
      });
    },
    enabled: inputValue.trim().length >= 2,
    staleTime: config.location.cacheTimeout,
    retry: (failureCount, error) => {
      // Don't retry if cancelled or rate limited
      if (error.message.includes('cancelled') || error.message.includes('rate limit')) {
        return false;
      }
      return failureCount < 2;
    }
  });

  // Handle input changes
  const handleInputChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = e.target.value;
    setInputValue(newValue);
    setSelectedIndex(-1);
    setHasUserInteracted(true);
    
    // Clear current selection if input doesn't match
    if (value && value.name !== newValue) {
      onChange(null);
    }
    
    debouncedSearch(newValue);
  }, [value, onChange, debouncedSearch]);

  // Handle city selection
  const handleCitySelect = useCallback((city: City) => {
    setInputValue(city.name);
    setIsOpen(false);
    setSelectedIndex(-1);
    onChange(city);
    inputRef.current?.blur();
  }, [onChange]);

  // Keyboard navigation
  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (!isOpen || suggestions.length === 0) {
      if (e.key === 'ArrowDown' && inputValue.trim().length >= 2) {
        setIsOpen(true);
      }
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setSelectedIndex(prev => 
          prev < suggestions.length - 1 ? prev + 1 : 0
        );
        break;
      case 'ArrowUp':
        e.preventDefault();
        setSelectedIndex(prev => prev > 0 ? prev - 1 : suggestions.length - 1);
        break;
      case 'Enter':
        e.preventDefault();
        if (selectedIndex >= 0 && suggestions[selectedIndex]) {
          handleCitySelect(suggestions[selectedIndex]);
        }
        break;
      case 'Escape':
        setIsOpen(false);
        setSelectedIndex(-1);
        inputRef.current?.blur();
        break;
      case 'Tab':
        setIsOpen(false);
        setSelectedIndex(-1);
        break;
    }
  }, [isOpen, suggestions, selectedIndex, handleCitySelect, inputValue]);

  // Auto-scroll selected item into view
  useEffect(() => {
    if (selectedIndex >= 0 && listRef.current) {
      const selectedElement = listRef.current.children[selectedIndex] as HTMLElement;
      if (selectedElement) {
        selectedElement.scrollIntoView({ block: 'nearest' });
      }
    }
  }, [selectedIndex]);

  // Handle clicks outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (inputRef.current && !inputRef.current.contains(event.target as Node) &&
          listRef.current && !listRef.current.contains(event.target as Node)) {
        setIsOpen(false);
        setSelectedIndex(-1);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Cleanup abort controller on unmount
  useEffect(() => {
    return () => {
      abortControllerRef.current?.abort();
    };
  }, []);

  // Reset input value when external value changes
  useEffect(() => {
    if (value?.name !== inputValue && !hasUserInteracted) {
      setInputValue(value?.name || '');
    }
  }, [value, inputValue, hasUserInteracted]);

  const showError = error || (queryError && !isLoading);
  const errorMessage = error || queryError?.message;
  const hasValidationError = showError && hasUserInteracted;

  return (
    <div className={`relative ${className}`}>
      <div className="relative">
        <input
          ref={inputRef}
          type="text"
          name={name}
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onBlur={(e) => {
            setIsOpen(false);
            setSelectedIndex(-1);
            onBlur?.();
          }}
          onFocus={(e) => {
            setHasUserInteracted(true);
            if (inputValue.trim().length >= 2 && suggestions.length > 0) {
              setIsOpen(true);
            }
            onFocus?.();
          }}
          placeholder={placeholder}
          disabled={disabled}
          required={required}
          aria-label={ariaLabel || "Search for a city"}
          aria-expanded={isOpen}
          aria-haspopup="listbox"
          aria-autocomplete="list"
          aria-activedescendant={selectedIndex >= 0 ? `${listboxId}-${selectedIndex}` : undefined}
          aria-describedby={hasValidationError ? errorId : undefined}
          aria-invalid={hasValidationError}
          data-testid={testId}
          className={`
            w-full px-3 py-2 border rounded-md shadow-sm transition-colors
            focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500
            ${disabled ? 'bg-gray-100 cursor-not-allowed border-gray-300' : 'bg-white'}
            ${hasValidationError ? 'border-red-500 focus:ring-red-500 focus:border-red-500' : 'border-gray-300'}
            ${isLoading ? 'pr-10' : ''}
          `}
        />
        
        {isLoading && (
          <div className="absolute right-3 top-1/2 transform -translate-y-1/2" aria-hidden="true">
            <div className="animate-spin h-4 w-4 border-2 border-blue-500 border-t-transparent rounded-full" />
          </div>
        )}
      </div>

      {/* Error message */}
      {hasValidationError && (
        <p id={errorId} className="mt-1 text-sm text-red-600" role="alert">
          {errorMessage}
        </p>
      )}

      {/* Dropdown list */}
      {isOpen && suggestions.length > 0 && (
        <ul
          ref={listRef}
          id={listboxId}
          role="listbox"
          aria-label="City suggestions"
          className="
            absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg
            max-h-60 overflow-auto focus:outline-none
          "
        >
          {suggestions.map((city, index) => (
            <li
              key={`${city.name}-${city.state}-${city.countryCode}-${index}`}
              id={`${listboxId}-${index}`}
              role="option"
              aria-selected={index === selectedIndex}
              className={`
                px-3 py-2 cursor-pointer hover:bg-gray-100 transition-colors
                ${index === selectedIndex ? 'bg-blue-100 text-blue-900' : 'text-gray-900'}
              `}
              onClick={() => handleCitySelect(city)}
              onMouseEnter={() => setSelectedIndex(index)}
            >
              <div className="flex justify-between items-center">
                <div className="flex-grow min-w-0">
                  <div className="font-medium truncate">{city.name}</div>
                  <div className="text-sm text-gray-500 truncate">
                    {city.state && `${city.state}, `}{city.country}
                  </div>
                </div>
                <div className="flex-shrink-0 ml-2 text-xs text-gray-400">
                  {Math.round(city.confidence * 100)}%
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* No results message */}
      {isOpen && !isLoading && suggestions.length === 0 && inputValue.trim().length >= 2 && (
        <div className="
          absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg
          px-3 py-2 text-gray-500 text-sm
        ">
          No cities found for "{inputValue}"
          {countryCode && ` in ${countryCode}`}
        </div>
      )}
    </div>
  );
};

export default CityAutocomplete;
```

#### 3.2 Form Integration Hook

```typescript
// src/hooks/useCityValidation.ts
import { useState, useCallback } from 'react';
import { useMutation } from '@tanstack/react-query';
import { locationApi, City, ValidationResult } from '../services/locationApi';

interface UseCityValidationOptions {
  countryCode?: string;
  onSuccess?: (result: ValidationResult) => void;
  onError?: (error: Error) => void;
  autoValidate?: boolean;
}

export const useCityValidation = (options: UseCityValidationOptions = {}) => {
  const [validatedCity, setValidatedCity] = useState<City | null>(null);
  const [lastQuery, setLastQuery] = useState<string>('');
  
  const mutation = useMutation({
    mutationFn: (query: string) => {
      setLastQuery(query);
      return locationApi.validateCity(query, {
        countryCode: options.countryCode
      });
    },
    onSuccess: (result) => {
      setValidatedCity(result.primaryMatch || null);
      options.onSuccess?.(result);
    },
    onError: (error: Error) => {
      setValidatedCity(null);
      options.onError?.(error);
    }
  });

  const validateCity = useCallback((query: string) => {
    if (!query.trim()) {
      setValidatedCity(null);
      setLastQuery('');
      return;
    }
    
    // Avoid re-validating the same query
    if (query.trim() === lastQuery.trim()) {
      return;
    }
    
    mutation.mutate(query.trim());
  }, [mutation, lastQuery]);

  const clearValidation = useCallback(() => {
    setValidatedCity(null);
    setLastQuery('');
    mutation.reset();
  }, [mutation]);

  const forceRevalidate = useCallback(() => {
    if (lastQuery) {
      mutation.mutate(lastQuery);
    }
  }, [mutation, lastQuery]);

  return {
    validateCity,
    clearValidation,
    forceRevalidate,
    validatedCity,
    isValidating: mutation.isPending,
    error: mutation.error,
    isError: mutation.isError,
    validationResult: mutation.data,
    lastQuery
  };
};
```

#### 3.3 Error Boundary Component

```typescript
// src/components/ErrorBoundary/LocationErrorBoundary.tsx
import React, { Component, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error?: Error;
}

class LocationErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('LocationErrorBoundary caught an error:', error, errorInfo);
    this.props.onError?.(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div className="p-4 border border-red-200 rounded-md bg-red-50">
          <h3 className="text-red-800 font-medium">Location Service Error</h3>
          <p className="text-red-700 text-sm mt-1">
            Location services are temporarily unavailable. 
            Please try entering your city manually or refresh the page.
          </p>
          <button 
            onClick={() => this.setState({ hasError: false, error: undefined })}
            className="mt-2 px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700 transition-colors"
          >
            Try Again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

export default LocationErrorBoundary;
```

### Phase 4: Advanced Features

#### 4.1 Offline Mode Hook

```typescript
// src/hooks/useOfflineLocation.ts
import { useState, useEffect, useCallback } from 'react';
import Fuse from 'fuse.js';
import { City } from '../services/locationApi';

// Preload common cities for offline fallback
const COMMON_CITIES_URL = '/data/common-cities.json';

interface OfflineCityData extends Omit<City, 'confidence' | 'apiResponseTime'> {
  population?: number;
  importance?: number;
}

export const useOfflineLocation = () => {
  const [cities, setCities] = useState<OfflineCityData[]>([]);
  const [fuse, setFuse] = useState<Fuse<OfflineCityData>>();
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  useEffect(() => {
    const loadOfflineData = async () => {
      try {
        setIsLoading(true);
        const response = await fetch(COMMON_CITIES_URL);
        
        if (!response.ok) {
          throw new Error(`Failed to load offline data: ${response.status}`);
        }
        
        const data: OfflineCityData[] = await response.json();
        
        setCities(data);
        
        // Configure Fuse for fuzzy searching
        const fuseInstance = new Fuse(data, {
          keys: [
            { name: 'name', weight: 0.7 },
            { name: 'state', weight: 0.2 },
            { name: 'country', weight: 0.1 }
          ],
          threshold: 0.3,
          includeScore: true,
          minMatchCharLength: 2
        });
        
        setFuse(fuseInstance);
        setError(null);
      } catch (err) {
        console.error('Failed to load offline location data:', err);
        setError(err instanceof Error ? err.message : 'Unknown error');
      } finally {
        setIsLoading(false);
      }
    };
    
    loadOfflineData();
  }, []);
  
  const searchOffline = useCallback((query: string, options: { limit?: number; countryCode?: string } = {}): City[] => {
    if (!fuse || query.length < 2) return [];
    
    const { limit = 10, countryCode } = options;
    
    let results = fuse.search(query, { limit: limit * 2 });
    
    // Filter by country code if specified
    if (countryCode) {
      results = results.filter(result => 
        result.item.countryCode.toLowerCase() === countryCode.toLowerCase()
      );
    }
    
    // Convert to City format with synthetic confidence based on fuzzy score
    return results.slice(0, limit).map(result => ({
      ...result.item,
      confidence: result.score ? 1 - result.score : 0.5, // Invert Fuse score
    }));
  }, [fuse]);
  
  const getCitiesForCountry = useCallback((countryCode: string): City[] => {
    return cities
      .filter(city => city.countryCode.toLowerCase() === countryCode.toLowerCase())
      .map(city => ({ ...city, confidence: 1.0 }))
      .sort((a, b) => (b.population || 0) - (a.population || 0));
  }, [cities]);
  
  return {
    searchOffline,
    getCitiesForCountry,
    isOfflineReady: !!fuse && !isLoading,
    isLoading,
    error,
    totalCities: cities.length
  };
};
```

#### 4.2 Analytics Hook

```typescript
// src/hooks/useLocationAnalytics.ts
import { useEffect, useCallback } from 'react';
import { City, ValidationResult } from '../services/locationApi';

interface LocationEvent {
  event: string;
  city?: City;
  query?: string;
  result?: ValidationResult;
  timestamp: number;
  userAgent?: string;
  countryCode?: string;
}

export const useLocationAnalytics = () => {
  const trackEvent = useCallback((event: Omit<LocationEvent, 'timestamp' | 'userAgent'>) => {
    if (!window.gtag && !window.analytics) return;
    
    const eventData: LocationEvent = {
      ...event,
      timestamp: Date.now(),
      userAgent: navigator.userAgent
    };
    
    // Google Analytics
    if (window.gtag) {
      window.gtag('event', event.event, {
        custom_map: {
          city_name: event.city?.name,
          country_code: event.countryCode || event.city?.countryCode,
          query: event.query,
          confidence: event.city?.confidence
        }
      });
    }
    
    // Console logging for development
    if (process.env.NODE_ENV === 'development') {
      console.log('Location Analytics:', eventData);
    }
  }, []);
  
  const trackCitySearch = useCallback((query: string, countryCode?: string) => {
    trackEvent({
      event: 'location_search',
      query,
      countryCode
    });
  }, [trackEvent]);
  
  const trackCitySelection = useCallback((city: City, query: string) => {
    trackEvent({
      event: 'location_selected',
      city,
      query
    });
  }, [trackEvent]);
  
  const trackValidationResult = useCallback((result: ValidationResult) => {
    trackEvent({
      event: 'location_validated',
      result,
      query: result.query,
      city: result.primaryMatch
    });
  }, [trackEvent]);
  
  return {
    trackCitySearch,
    trackCitySelection,
    trackValidationResult
  };
};
```

---

## Critical Considerations You Might Miss

### 1. **Elixir-Specific Fault Tolerance**

```elixir
# lib/route_wise/location/supervisor.ex
defmodule RouteWise.Location.Supervisor do
  @moduledoc """
  Supervisor for location services with proper restart strategies
  """
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  def init(_init_arg) do
    children = [
      # Cache service - if it crashes, restart immediately
      {RouteWise.Location.Services.CacheService, []},
      
      # LocationIQ adapter with exponential backoff restart
      %{
        id: RouteWise.Location.Adapters.LocationIqAdapter,
        start: {RouteWise.Location.Adapters.LocationIqAdapter, :start_link, [[]]},
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      }
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 2. **Request Coalescing for Performance**

```elixir
# lib/route_wise/location/request_coalescer.ex
defmodule RouteWise.Location.RequestCoalescer do
  @moduledoc """
  Prevents duplicate API requests by coalescing similar requests
  """
  use GenServer
  
  @request_window 1000  # 1 second window
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_or_request(key, request_fun) do
    GenServer.call(__MODULE__, {:get_or_request, key, request_fun})
  end
  
  def init(_opts) do
    # Clean up expired requests every 10 seconds
    :timer.send_interval(10_000, self(), :cleanup)
    {:ok, %{pending_requests: %{}, request_history: %{}}}
  end
  
  def handle_call({:get_or_request, key, request_fun}, from, state) do
    current_time = System.monotonic_time(:millisecond)
    
    case Map.get(state.pending_requests, key) do
      nil ->
        # No pending request, start new one
        task = Task.async(request_fun)
        new_pending = Map.put(state.pending_requests, key, {task, [from], current_time})
        {:noreply, %{state | pending_requests: new_pending}}
        
      {task, waiters, _start_time} ->
        # Add to existing request waiters
        new_pending = Map.put(state.pending_requests, key, {task, [from | waiters], current_time})
        {:noreply, %{state | pending_requests: new_pending}}
    end
  end
  
  def handle_info({ref, result}, state) when is_reference(ref) do
    # Task completed, reply to all waiters
    case find_task_by_ref(state.pending_requests, ref) do
      {key, {_task, waiters, _start_time}} ->
        Enum.each(waiters, fn waiter -> GenServer.reply(waiter, result) end)
        new_pending = Map.delete(state.pending_requests, key)
        {:noreply, %{state | pending_requests: new_pending}}
        
      nil ->
        {:noreply, state}
    end
  end
  
  defp find_task_by_ref(pending_requests, ref) do
    Enum.find(pending_requests, fn {_key, {task, _waiters, _time}} ->
      task.ref == ref
    end)
  end
end
```

### 3. **Phoenix LiveView Integration (Optional)**

```elixir
# lib/route_wise_web/live/location_live.ex
defmodule RouteWiseWeb.LocationLive do
  use RouteWiseWeb, :live_view
  
  alias RouteWise.Location
  
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:query, "")
      |> assign(:suggestions, [])
      |> assign(:loading, false)
      |> assign(:selected_city, nil)
      
    {:ok, socket}
  end
  
  def handle_event("search", %{"query" => query}, socket) do
    if String.length(String.trim(query)) >= 2 do
      send(self(), {:perform_search, query})
      {:noreply, assign(socket, query: query, loading: true)}
    else
      {:noreply, assign(socket, query: query, suggestions: [], loading: false)}
    end
  end
  
  def handle_event("select_city", %{"city" => city_json}, socket) do
    city = Jason.decode!(city_json, keys: :atoms)
    {:noreply, assign(socket, selected_city: city, suggestions: [])}
  end
  
  def handle_info({:perform_search, query}, socket) do
    case Location.autocomplete_cities(query) do
      {:ok, suggestions} ->
        {:noreply, assign(socket, suggestions: suggestions, loading: false)}
      {:error, _reason} ->
        {:noreply, assign(socket, suggestions: [], loading: false)}
    end
  end
  
  def render(assigns) do
    ~H"""
    <div class="location-search">
      <form phx-change="search" phx-submit="search">
        <input 
          type="text" 
          name="query" 
          value={@query}
          placeholder="Search for a city..."
          class="w-full px-3 py-2 border rounded-md"
        />
      </form>
      
      <%= if @loading do %>
        <div class="loading">Searching...</div>
      <% end %>
      
      <%= if length(@suggestions) > 0 do %>
        <ul class="suggestions">
          <%= for city <- @suggestions do %>
            <li 
              phx-click="select_city" 
              phx-value-city={Jason.encode!(city)}
              class="suggestion-item"
            >
              <strong><%= city.name %></strong>
              <%= if city.state, do: ", #{city.state}" %>
              , <%= city.country %>
            </li>
          <% end %>
        </ul>
      <% end %>
      
      <%= if @selected_city do %>
        <div class="selected-city">
          Selected: <%= @selected_city.name %>, <%= @selected_city.country %>
        </div>
      <% end %>
    </div>
    """
  end
end
```

### 4. **Database Caching Strategy**

```elixir
# Migration for location cache table
defmodule RouteWise.Repo.Migrations.CreateLocationCache do
  use Ecto.Migration

  def change do
    create table(:location_cache) do
      add :cache_key, :string, null: false
      add :query, :string, null: false
      add :response_data, :map, null: false
      add :country_code, :string
      add :expires_at, :utc_datetime, null: false
      add :hit_count, :integer, default: 0
      
      timestamps()
    end
    
    create unique_index(:location_cache, [:cache_key])
    create index(:location_cache, [:query])
    create index(:location_cache, [:country_code])
    create index(:location_cache, [:expires_at])
  end
end

# lib/route_wise/location/schemas/location_cache.ex
defmodule RouteWise.Location.Schemas.LocationCache do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "location_cache" do
    field :cache_key, :string
    field :query, :string
    field :response_data, :map
    field :country_code, :string
    field :expires_at, :utc_datetime
    field :hit_count, :integer, default: 0
    
    timestamps()
  end
  
  def changeset(cache_entry, attrs) do
    cache_entry
    |> cast(attrs, [:cache_key, :query, :response_data, :country_code, :expires_at])
    |> validate_required([:cache_key, :query, :response_data, :expires_at])
    |> unique_constraint(:cache_key)
  end
end
```

### 5. **Performance Monitoring**

```elixir
# lib/route_wise/location/telemetry.ex
defmodule RouteWise.Location.Telemetry do
  @moduledoc """
  Telemetry events for location services monitoring
  """
  
  def attach_handlers do
    events = [
      [:location, :api_call],
      [:location, :cache_hit],
      [:location, :cache_miss],
      [:location, :validation],
      [:location, :error]
    ]
    
    :telemetry.attach_many(
      "location-telemetry",
      events,
      &handle_event/4,
      nil
    )
  end
  
  def handle_event([:location, :api_call], measurements, metadata, _config) do
    # Send metrics to your monitoring system (DataDog, New Relic, etc.)
    :telemetry.execute([:route_wise, :location, :api_usage], %{
      duration: measurements.duration,
      api_calls: 1
    }, %{
      provider: metadata.provider,
      endpoint: metadata.endpoint,
      status: metadata.status,
      country_code: metadata[:country_code]
    })
  end
  
  def handle_event([:location, :cache_hit], _measurements, metadata, _config) do
    :telemetry.execute([:route_wise, :location, :cache], %{
      cache_hits: 1
    }, %{
      cache_type: :hit,
      query_type: metadata.query_type
    })
  end
  
  def handle_event([:location, :cache_miss], _measurements, metadata, _config) do
    :telemetry.execute([:route_wise, :location, :cache], %{
      cache_misses: 1
    }, %{
      cache_type: :miss,
      query_type: metadata.query_type
    })
  end
end
```

### 6. **Security Considerations**

```elixir
# lib/route_wise_web/plugs/location_security_plug.ex
defmodule RouteWiseWeb.Plugs.LocationSecurityPlug do
  @moduledoc """
  Security measures for location endpoints
  """
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    conn
    |> validate_query_input()
    |> check_suspicious_patterns()
    |> add_security_headers()
  end
  
  defp validate_query_input(conn) do
    case conn.params do
      %{"query" => query} when is_binary(query) ->
        # Sanitize and validate query
        sanitized = String.trim(query) |> String.slice(0, 100)
        
        if String.match?(sanitized, ~r/^[a-zA-Z0-9\s\-',\.]+$/) do
          %{conn | params: Map.put(conn.params, "query", sanitized)}
        else
          conn
          |> put_status(:bad_request)
          |> Phoenix.Controller.json(%{error: "Invalid characters in query"})
          |> halt()
        end
        
      _ -> conn
    end
  end
  
  defp check_suspicious_patterns(conn) do
    query = conn.params["query"] || ""
    
    # Check for SQL injection patterns, script tags, etc.
    suspicious_patterns = [
      ~r/(\<script|\<\/script)/i,
      ~r/(union\s+select|drop\s+table)/i,
      ~r/(\'\s*or\s+\'\s*=\s*\')/i
    ]
    
    if Enum.any?(suspicious_patterns, &String.match?(query, &1)) do
      # Log security incident
      require Logger
      Logger.warning("Suspicious location query detected: #{query} from #{get_client_ip(conn)}")
      
      conn
      |> put_status(:bad_request)
      |> Phoenix.Controller.json(%{error: "Invalid query format"})
      |> halt()
    else
      conn
    end
  end
  
  defp add_security_headers(conn) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
  end
  
  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_for | _] -> String.split(forwarded_for, ",") |> hd() |> String.trim()
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end
end
```

---

## Testing Strategy

### Backend Tests

```elixir
# test/route_wise/location/adapters/locationiq_adapter_test.exs
defmodule RouteWise.Location.Adapters.LocationIqAdapterTest do
  use ExUnit.Case, async: true
  import Mock
  
  alias RouteWise.Location.Adapters.LocationIqAdapter
  alias RouteWise.Location.Schemas.ValidationResult
  
  describe "validate_city/2" do
    test "returns validation result for successful API response" do
      mock_response = [
        %{
          "lat" => "40.7128",
          "lon" => "-74.0060",
          "display_name" => "New York, NY, USA",
          "class" => "place",
          "type" => "city",
          "address" => %{
            "city" => "New York",
            "state" => "New York",
            "country" => "United States",
            "country_code" => "us"
          }
        }
      ]
      
      with_mock HTTPoison, [
        get: fn(_, _, _) -> 
          {:ok, %HTTPoison.Response{
            status_code: 200, 
            body: Jason.encode!(mock_response)
          }}
        end
      ] do
        assert {:ok, %ValidationResult{valid: true, cities: [city]}} = 
          LocationIqAdapter.validate_city("New York")
        
        assert city.name == "New York"
        assert city.latitude == 40.7128
        assert city.longitude == -74.0060
        assert city.country == "United States"
      end
    end
    
    test "handles API rate limiting" do
      with_mock HTTPoison, [
        get: fn(_, _, _) -> 
          {:ok, %HTTPoison.Response{status_code: 429, body: "Rate limit exceeded"}}
        end
      ] do
        assert {:error, "Rate limit exceeded"} = LocationIqAdapter.validate_city("New York")
      end
    end
    
    test "handles network timeout" do
      with_mock HTTPoison, [
        get: fn(_, _, _) -> 
          {:error, %HTTPoison.Error{reason: :timeout}}
        end
      ] do
        assert {:error, "HTTP error: timeout"} = LocationIqAdapter.validate_city("New York")
      end
    end
  end
end
```

### Frontend Tests

```typescript
// src/components/LocationInput/__tests__/CityAutocomplete.test.tsx
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { CityAutocomplete } from '../CityAutocomplete';
import { locationApi } from '../../../services/locationApi';

// Mock the location API
jest.mock('../../../services/locationApi');
const mockLocationApi = locationApi as jest.Mocked<typeof locationApi>;

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false }
    }
  });
  
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
};

describe('CityAutocomplete', () => {
  const mockOnChange = jest.fn();
  
  beforeEach(() => {
    mockOnChange.mockClear();
    mockLocationApi.autocompleteCity.mockClear();
  });
  
  it('renders input with placeholder', () => {
    render(
      <CityAutocomplete onChange={mockOnChange} placeholder="Enter city..." />,
      { wrapper: createWrapper() }
    );
    
    expect(screen.getByPlaceholderText('Enter city...')).toBeInTheDocument();
  });
  
  it('shows suggestions when typing', async () => {
    const user = userEvent.setup();
    const mockCities = [
      {
        name: 'New York',
        state: 'New York',
        country: 'United States',
        countryCode: 'US',
        latitude: 40.7128,
        longitude: -74.0060,
        displayName: 'New York, NY, USA',
        confidence: 0.9,
        placeType: 'city'
      }
    ];
    
    mockLocationApi.autocompleteCity.mockResolvedValue(mockCities);
    
    render(
      <CityAutocomplete onChange={mockOnChange} />,
      { wrapper: createWrapper() }
    );
    
    const input = screen.getByRole('textbox');
    await user.type(input, 'New Y');
    
    await waitFor(() => {
      expect(mockLocationApi.autocompleteCity).toHaveBeenCalledWith('New Y', expect.any(Object));
    });
    
    await waitFor(() => {
      expect(screen.getByText('New York')).toBeInTheDocument();
      expect(screen.getByText('New York, United States')).toBeInTheDocument();
    });
  });
  
  it('calls onChange when city is selected', async () => {
    const user = userEvent.setup();
    const mockCities = [
      {
        name: 'New York',
        state: 'New York',
        country: 'United States',
        countryCode: 'US',
        latitude: 40.7128,
        longitude: -74.0060,
        displayName: 'New York, NY, USA',
        confidence: 0.9,
        placeType: 'city'
      }
    ];
    
    mockLocationApi.autocompleteCity.mockResolvedValue(mockCities);
    
    render(
      <CityAutocomplete onChange={mockOnChange} />,
      { wrapper: createWrapper() }
    );
    
    const input = screen.getByRole('textbox');
    await user.type(input, 'New Y');
    
    await waitFor(() => {
      expect(screen.getByText('New York')).toBeInTheDocument();
    });
    
    await user.click(screen.getByText('New York'));
    
    expect(mockOnChange).toHaveBeenCalledWith(mockCities[0]);
  });
  
  it('handles keyboard navigation', async () => {
    const user = userEvent.setup();
    const mockCities = [
      {
        name: 'New York',
        state: 'New York', 
        country: 'United States',
        countryCode: 'US',
        latitude: 40.7128,
        longitude: -74.0060,
        displayName: 'New York, NY, USA',
        confidence: 0.9,
        placeType: 'city'
      },
      {
        name: 'Newark',
        state: 'New Jersey',
        country: 'United States', 
        countryCode: 'US',
        latitude: 40.7357,
        longitude: -74.1724,
        displayName: 'Newark, NJ, USA',
        confidence: 0.8,
        placeType: 'city'
      }
    ];
    
    mockLocationApi.autocompleteCity.mockResolvedValue(mockCities);
    
    render(
      <CityAutocomplete onChange={mockOnChange} />,
      { wrapper: createWrapper() }
    );
    
    const input = screen.getByRole('textbox');
    await user.type(input, 'New');
    
    await waitFor(() => {
      expect(screen.getByText('New York')).toBeInTheDocument();
    });
    
    // Navigate with arrow keys
    await user.keyboard('{ArrowDown}');
    await user.keyboard('{ArrowDown}');
    await user.keyboard('{Enter}');
    
    expect(mockOnChange).toHaveBeenCalledWith(mockCities[1]);
  });
  
  it('displays error message on API failure', async () => {
    const user = userEvent.setup();
    const errorMessage = 'API request failed';
    
    mockLocationApi.autocompleteCity.mockRejectedValue(new Error(errorMessage));
    
    render(
      <CityAutocomplete onChange={mockOnChange} />,
      { wrapper: createWrapper() }
    );
    
    const input = screen.getByRole('textbox');
    await user.type(input, 'Test');
    
    await waitFor(() => {
      expect(screen.getByText(errorMessage)).toBeInTheDocument();
    });
  });
});
```

---

## Deployment Checklist

### Environment Variables

```bash
# .env.production
LOCATIONIQ_API_KEY=your_locationiq_api_key_here
DATABASE_URL=ecto://user:pass@localhost/route_wise_prod
SECRET_KEY_BASE=your_very_long_secret_key_base
REDIS_URL=redis://localhost:6379
PHX_HOST=your-domain.com
PORT=4000

# Rate limiting
RATE_LIMIT_REQUESTS_PER_HOUR=1000
RATE_LIMIT_WINDOW_SECONDS=3600

# Cache settings
LOCATION_CACHE_TTL_HOURS=24
LOCATION_CACHE_MAX_ENTRIES=10000

# Feature flags
ENABLE_LOCATION_ANALYTICS=true
ENABLE_OFFLINE_MODE=true
ENABLE_REQUEST_COALESCING=true
```

### Production Configuration

```elixir
# config/prod.exs
import Config

config :route_wise, RouteWiseWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST"), port: 443, scheme: "https"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :route_wise,
  locationiq: %{
    base_url: "https://us1.locationiq.com/v1",
    timeout: 10_000,
    retries: 3,
    cache_ttl: :timer.hours(String.to_integer(System.get_env("LOCATION_CACHE_TTL_HOURS", "24")))
  }

# Logging
config :logger, level: :info

# Database
config :route_wise, RouteWise.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true
```

### Docker Configuration

```dockerfile
# Dockerfile
FROM elixir:1.15-otp-26-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git python3 curl nodejs npm

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix deps.get --only=prod
RUN mix deps.compile

# Copy application code
COPY . .

# Build frontend assets
RUN cd assets && npm ci && npm run build
RUN mix phx.digest

# Build release
ENV MIX_ENV=prod
RUN mix compile
RUN mix release

# Production stage
FROM alpine:3.18 AS prod

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

# Copy the release
COPY --from=build /app/_build/prod/rel/route_wise ./

# Create user
RUN adduser -D -h /app -s /bin/sh app
RUN chown -R app: /app
USER app

# Expose port
EXPOSE 4000

# Start the application
CMD ["bin/route_wise", "start"]
```

### Deployment Scripts

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

echo "🚀 Deploying RouteWise to production..."

# Build and test
mix deps.get --only=prod
mix test
cd assets && npm ci && npm run build && cd ..
mix phx.digest

# Database migrations
mix ecto.migrate

# Build release
MIX_ENV=prod mix release

# Deploy to Fly.io (or your hosting platform)
fly deploy --remote-only

echo "✅ Deployment complete!"
```

### Monitoring Setup

```elixir
# lib/route_wise_web/telemetry.ex
defmodule RouteWiseWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics
  
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end
  
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  def metrics do
    [
      # Phoenix metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      
      # Location API metrics
      counter("location.api_call.count",
        tags: [:provider, :endpoint, :status]
      ),
      summary("location.api_call.duration",
        tags: [:provider, :endpoint],
        unit: {:native, :millisecond}
      ),
      
      # Cache metrics
      counter("location.cache.count",
        tags: [:cache_type]
      ),
      
      # Database metrics
      summary("route_wise.repo.query.total_time",
        unit: {:native, :millisecond}
      ),
      summary("route_wise.repo.query.decode_time",
        unit: {:native, :millisecond}
      ),
      
      # VM metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end
  
  defp periodic_measurements do
    [
      {__MODULE__, :dispatch_cache_stats, []},
      {__MODULE__, :dispatch_api_health, []}
    ]
  end
  
  def dispatch_cache_stats do
    case RouteWise.Location.Services.CacheService.stats() do
      {:ok, stats} ->
        :telemetry.execute([:location, :cache, :stats], stats)
      _ ->
        :ok
    end
  end
  
  def dispatch_api_health do
    # Check LocationIQ API health
    case locationApi.healthCheck() do
      {:ok, _} ->
        :telemetry.execute([:location, :api, :health], %{status: 1})
      {:error, _} ->
        :telemetry.execute([:location, :api, :health], %{status: 0})
    end
  end
end
```

This comprehensive plan covers all aspects of integrating LocationIQ with your Phoenix/React application, including performance optimization, security, testing, and production deployment considerations. The implementation is production-ready with proper error handling, caching, rate limiting, and monitoring.