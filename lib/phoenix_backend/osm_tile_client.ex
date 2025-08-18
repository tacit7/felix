defmodule RouteWiseApi.OSMTileClient do
  @moduledoc """
  OpenStreetMap tile client with Finch integration, rate limiting, and retry logic.

  Fetches map tiles from OSM tile servers while respecting usage policies and
  implementing robust error handling. Integrates with existing Finch HTTP client
  infrastructure and follows OSM tile usage guidelines.

  ## Features

  - **Rate Limiting**: Respects OSM server policies (max 2 requests/second)
  - **Server Load Balancing**: Distributes requests across multiple OSM servers
  - **Retry Logic**: Exponential backoff for failed requests
  - **Proper Headers**: OSM-compliant User-Agent and request headers
  - **Error Handling**: Comprehensive error categorization and logging

  ## OSM Tile Usage Policy Compliance

  - User-Agent header identifies the application
  - Rate limiting prevents server overload
  - Load balancing reduces individual server stress
  - Caching reduces repeated requests for same tiles

  ## Configuration

      config :phoenix_backend, RouteWiseApi.OSMTileClient,
        user_agent: "RouteWise/1.0 (contact@example.com)",
        max_requests_per_second: 2,
        max_retries: 3,
        timeout_ms: 10_000,
        servers: [
          "https://tile.openstreetmap.org",
          "https://a.tile.openstreetmap.org", 
          "https://b.tile.openstreetmap.org",
          "https://c.tile.openstreetmap.org"
        ]

  ## Usage

      # Fetch a single tile
      {:ok, png_binary} = RouteWiseApi.OSMTileClient.fetch_tile(10, 511, 383)

      # Handle errors
      {:error, :not_found} = RouteWiseApi.OSMTileClient.fetch_tile(0, 999, 999)
      {:error, :timeout} = RouteWiseApi.OSMTileClient.fetch_tile(15, 1024, 768)

  ## Error Types

  - `:not_found` - Tile does not exist (404)
  - `:timeout` - Request timed out
  - `:rate_limited` - Too many requests (429) 
  - `:server_error` - OSM server error (5xx)
  - `:network_error` - Network connectivity issues
  - `:invalid_response` - Unexpected response format
  """

  require Logger

  @default_config %{
    user_agent: "RouteWise/1.0 (contact@example.com)",
    max_requests_per_second: 2,
    max_retries: 3,
    timeout_ms: 10_000,
    servers: [
      "https://tile.openstreetmap.org",
      "https://a.tile.openstreetmap.org",
      "https://b.tile.openstreetmap.org", 
      "https://c.tile.openstreetmap.org"
    ]
  }

  @doc """
  Fetch a tile from OSM servers.

  ## Parameters
  - `z`: Zoom level (0-19)
  - `x`: Tile X coordinate
  - `y`: Tile Y coordinate
  - `opts`: Optional configuration overrides

  ## Returns
  - `{:ok, binary}` - PNG tile data
  - `{:error, reason}` - Error with categorized reason

  ## Examples

      {:ok, png_data} = RouteWiseApi.OSMTileClient.fetch_tile(10, 511, 383)
      {:error, :not_found} = RouteWiseApi.OSMTileClient.fetch_tile(0, 999, 999)

  """
  def fetch_tile(z, x, y, opts \\ []) do
    config = get_config(opts)
    
    with :ok <- rate_limit_check(),
         {:ok, url} <- build_tile_url(z, x, y, config),
         {:ok, response} <- fetch_with_retry(url, config) do
      {:ok, response}
    else
      {:error, reason} = error ->
        Logger.warning("Failed to fetch tile #{z}/#{x}/#{y}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Build the URL for a specific tile.

  ## Examples

      {:ok, "https://tile.openstreetmap.org/10/511/383.png"} = 
        RouteWiseApi.OSMTileClient.build_tile_url(10, 511, 383)

  """
  def build_tile_url(z, x, y, config \\ %{}) do
    config = Map.merge(@default_config, config)
    
    case validate_tile_coordinates(z, x, y) do
      :ok ->
        server = select_server(config.servers, z, x, y)
        url = "#{server}/#{z}/#{x}/#{y}.png"
        {:ok, url}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if the rate limiter allows the request.
  Implements a simple token bucket algorithm.
  """
  def rate_limit_check do
    case GenServer.call(__MODULE__.RateLimiter, :check_rate_limit, 1000) do
      :ok -> :ok
      :rate_limited -> {:error, :rate_limited}
    end
  rescue
    _ ->
      # If rate limiter is not available, allow the request
      :ok
  end

  @doc """
  Get current rate limiter statistics.

  ## Returns

      %{
        requests_this_second: 1,
        requests_per_second_limit: 2,
        tokens_remaining: 1
      }

  """
  def rate_limit_stats do
    try do
      GenServer.call(__MODULE__.RateLimiter, :stats, 1000)
    rescue
      _ -> %{error: "Rate limiter not available"}
    end
  end

  ## Private Functions

  defp get_config(opts) do
    app_config = Application.get_env(:phoenix_backend, __MODULE__, [])
    app_config_map = Enum.into(app_config, %{})
    
    @default_config
    |> Map.merge(app_config_map)
    |> Map.merge(Enum.into(opts, %{}))
  end

  defp validate_tile_coordinates(z, x, y) do
    max_coord = trunc(:math.pow(2, z))
    
    cond do
      z < 0 or z > 19 ->
        {:error, :invalid_zoom}
      
      x < 0 or x >= max_coord ->
        {:error, :invalid_x_coordinate}
      
      y < 0 or y >= max_coord ->
        {:error, :invalid_y_coordinate}
      
      true ->
        :ok
    end
  end

  defp select_server(servers, z, x, y) do
    # Use tile coordinates to deterministically select server
    # This provides consistent load balancing
    index = rem(z + x + y, length(servers))
    Enum.at(servers, index)
  end

  defp fetch_with_retry(url, config, attempt \\ 1) do
    headers = build_headers(config)
    request_opts = [timeout: config.timeout_ms]
    
    case Finch.build(:get, url, headers) |> Finch.request(RouteWiseApi.Finch, request_opts) do
      {:ok, %Finch.Response{status: 200, body: body, headers: response_headers}} ->
        case validate_png_response(body, response_headers) do
          :ok -> {:ok, body}
          {:error, reason} -> {:error, reason}
        end
      
      {:ok, %Finch.Response{status: 404}} ->
        {:error, :not_found}
      
      {:ok, %Finch.Response{status: 429}} ->
        if attempt <= config.max_retries do
          backoff_delay = calculate_backoff_delay(attempt)
          Logger.warning("Rate limited, retrying in #{backoff_delay}ms (attempt #{attempt})")
          Process.sleep(backoff_delay)
          fetch_with_retry(url, config, attempt + 1)
        else
          {:error, :rate_limited}
        end
      
      {:ok, %Finch.Response{status: status}} when status >= 500 ->
        if attempt <= config.max_retries do
          backoff_delay = calculate_backoff_delay(attempt)
          Logger.warning("Server error #{status}, retrying in #{backoff_delay}ms (attempt #{attempt})")
          Process.sleep(backoff_delay)
          fetch_with_retry(url, config, attempt + 1)
        else
          {:error, :server_error}
        end
      
      {:ok, %Finch.Response{status: status}} ->
        Logger.warning("Unexpected HTTP status: #{status}")
        {:error, {:http_error, status}}
      
      {:error, %Mint.TransportError{reason: :timeout}} ->
        if attempt <= config.max_retries do
          backoff_delay = calculate_backoff_delay(attempt)
          Logger.warning("Request timeout, retrying in #{backoff_delay}ms (attempt #{attempt})")
          Process.sleep(backoff_delay)
          fetch_with_retry(url, config, attempt + 1)
        else
          {:error, :timeout}
        end
      
      {:error, reason} ->
        Logger.error("Network error fetching tile: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp build_headers(config) do
    [
      {"User-Agent", config.user_agent},
      {"Accept", "image/png"},
      {"Accept-Encoding", "gzip, deflate"},
      {"Connection", "keep-alive"}
    ]
  end

  defp validate_png_response(body, headers) do
    content_type = get_header_value(headers, "content-type")
    
    cond do
      byte_size(body) == 0 ->
        {:error, :empty_response}
      
      content_type && not String.contains?(content_type, "image") ->
        {:error, :invalid_content_type}
      
      not is_png_data?(body) ->
        {:error, :invalid_png_data}
      
      true ->
        :ok
    end
  end

  defp get_header_value(headers, key) do
    headers
    |> Enum.find(fn {k, _v} -> String.downcase(k) == String.downcase(key) end)
    |> case do
      {_key, value} -> value
      nil -> nil
    end
  end

  defp is_png_data?(<<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>>), do: true
  defp is_png_data?(_), do: false

  defp calculate_backoff_delay(attempt) do
    # Exponential backoff: 500ms, 1s, 2s, 4s...
    base_delay = 500
    trunc(base_delay * :math.pow(2, attempt - 1))
  end

  ## Rate Limiter GenServer

  defmodule RateLimiter do
    @moduledoc """
    Token bucket rate limiter for OSM tile requests.
    
    Implements a simple token bucket algorithm to respect OSM server policies.
    Refills tokens at a configured rate (default: 2 per second).
    """
    
    use GenServer
    require Logger

    defstruct tokens: 0,
              max_tokens: 2,
              refill_rate: 2,
              last_refill: 0,
              total_requests: 0,
              rate_limited_requests: 0

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(_opts) do
      config = Application.get_env(:phoenix_backend, RouteWiseApi.OSMTileClient, %{})
      max_requests_per_second = Keyword.get(config, :max_requests_per_second, 2)
      
      # Start with full bucket
      state = %__MODULE__{
        tokens: max_requests_per_second,
        max_tokens: max_requests_per_second,
        refill_rate: max_requests_per_second,
        last_refill: System.system_time(:millisecond)
      }
      
      # Schedule token refill every 500ms
      Process.send_after(self(), :refill_tokens, 500)
      
      Logger.info("OSM Rate Limiter started: #{max_requests_per_second} requests/second")
      {:ok, state}
    end

    def handle_call(:check_rate_limit, _from, state) do
      new_state = refill_tokens_if_needed(state)
      
      if new_state.tokens > 0 do
        final_state = %{new_state |
          tokens: new_state.tokens - 1,
          total_requests: new_state.total_requests + 1
        }
        {:reply, :ok, final_state}
      else
        rate_limited_state = %{new_state |
          rate_limited_requests: new_state.rate_limited_requests + 1
        }
        {:reply, :rate_limited, rate_limited_state}
      end
    end

    def handle_call(:stats, _from, state) do
      stats = %{
        tokens_remaining: state.tokens,
        max_tokens: state.max_tokens,
        total_requests: state.total_requests,
        rate_limited_requests: state.rate_limited_requests,
        rate_limit_percentage: 
          if state.total_requests > 0 do
            Float.round(state.rate_limited_requests / state.total_requests * 100, 2)
          else
            0.0
          end
      }
      {:reply, stats, state}
    end

    def handle_info(:refill_tokens, state) do
      new_state = refill_tokens_if_needed(state)
      Process.send_after(self(), :refill_tokens, 500)
      {:noreply, new_state}
    end

    defp refill_tokens_if_needed(state) do
      current_time = System.system_time(:millisecond)
      time_elapsed = current_time - state.last_refill
      
      if time_elapsed >= 1000 do  # Refill every second
        tokens_to_add = state.refill_rate
        new_tokens = min(state.tokens + tokens_to_add, state.max_tokens)
        
        %{state |
          tokens: new_tokens,
          last_refill: current_time
        }
      else
        state
      end
    end
  end
end