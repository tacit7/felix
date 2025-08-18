defmodule RouteWiseApiWeb.TileController do
  @moduledoc """
  OSM tile proxy controller with caching, validation, and performance optimization.

  Serves map tiles through a cache-first strategy that dramatically reduces
  frontend network requests while maintaining OSM compliance. Integrates with
  the existing Phoenix architecture and error handling patterns.

  ## Features

  - **Cache-First Strategy**: Check cache before fetching from OSM
  - **Parameter Validation**: Validate z/x/y coordinates and ranges
  - **HTTP Optimization**: Proper caching headers, ETags, compression
  - **Error Handling**: Comprehensive error responses with proper status codes
  - **Performance Monitoring**: Request metrics and cache statistics
  - **OSM Compliance**: Respects tile server policies and usage guidelines

  ## Route

      GET /api/tiles/:z/:x/:y.png

  ## Examples

      # Valid tile request
      GET /api/tiles/10/511/383.png
      -> 200 OK with PNG binary data and cache headers

      # Invalid coordinates  
      GET /api/tiles/25/0/0.png
      -> 400 Bad Request with error details

      # OSM server unavailable
      GET /api/tiles/15/1024/768.png  
      -> 502 Bad Gateway with retry suggestion

  ## Response Headers

  - `Content-Type: image/png`
  - `Cache-Control: public, max-age=604800` (7 days)
  - `ETag: "tile-z-x-y-checksum"` for efficient caching
  - `Content-Encoding: gzip` when beneficial
  - `X-Cache-Status: HIT|MISS` for debugging

  ## Error Responses

  - `400` - Invalid tile coordinates
  - `404` - Tile not found 
  - `429` - Rate limited (too many requests)
  - `502` - OSM server error or timeout
  - `503` - Cache service unavailable
  """

  use RouteWiseApiWeb, :controller
  
  require Logger

  @doc """
  Serve a map tile with cache-first strategy.

  ## Parameters
  - `z`: Zoom level (0-19)
  - `x`: Tile X coordinate
  - `y`: Tile Y coordinate

  ## Query Parameters
  - `format`: Image format (default: png, only png supported)
  - `refresh`: Force refresh from source (cache bypass)

  ## Process Flow
  1. Validate tile coordinates
  2. Check cache for existing tile
  3. If cache miss, fetch from OSM
  4. Store in cache for future requests
  5. Return tile with appropriate headers
  """
  def tile(conn, %{"z" => z_str, "x" => x_str, "y" => y_str} = params) do
    with {:ok, z, x, y} <- parse_coordinates(z_str, x_str, y_str),
         {:ok, tile_data, cache_status} <- get_tile_data(z, x, y, params) do
      
      conn
      |> put_tile_headers(z, x, y, cache_status)
      |> put_resp_content_type("image/png")
      |> send_resp(200, tile_data)
    else
      {:error, :invalid_coordinates, reason} ->
        Logger.warning("Invalid tile coordinates: z=#{z_str}, x=#{x_str}, y=#{y_str} - #{reason}")
        
        conn
        |> put_status(400)
        |> json(%{
          error: "Invalid tile coordinates",
          details: reason,
          valid_ranges: %{
            z: "0-19",
            x: "0 to 2^z - 1", 
            y: "0 to 2^z - 1"
          }
        })
      
      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{
          error: "Tile not found",
          message: "The requested tile does not exist on the OSM servers"
        })
      
      {:error, :rate_limited} ->
        conn
        |> put_resp_header("Retry-After", "60")
        |> put_status(429)
        |> json(%{
          error: "Rate limited",
          message: "Too many tile requests. Please slow down.",
          retry_after_seconds: 60
        })
      
      {:error, :timeout} ->
        conn
        |> put_status(502)
        |> json(%{
          error: "Gateway timeout", 
          message: "OSM tile servers are currently slow to respond. Please try again."
        })
      
      {:error, :server_error} ->
        conn
        |> put_status(502)
        |> json(%{
          error: "Bad gateway",
          message: "OSM tile servers are experiencing issues. Please try again later."
        })
      
      {:error, :cache_unavailable} ->
        conn
        |> put_status(503)
        |> json(%{
          error: "Service unavailable",
          message: "Tile cache service is temporarily unavailable"
        })
      
      {:error, reason} ->
        Logger.error("Unexpected error serving tile #{z_str}/#{x_str}/#{y_str}: #{inspect(reason)}")
        
        conn
        |> put_status(500)
        |> json(%{
          error: "Internal server error",
          message: "An unexpected error occurred while processing the tile request"
        })
    end
  end

  @doc """
  Get tile cache statistics and health information.
  Useful for monitoring and debugging.

  ## Route
      GET /api/tiles/stats

  ## Response
      {
        "cache": {
          "hits": 1250,
          "misses": 200,
          "hit_rate": 0.862,
          "memory_mb": 45.2,
          "total_stored": 1400
        },
        "rate_limiter": {
          "tokens_remaining": 2,
          "total_requests": 450,
          "rate_limited_requests": 5
        },
        "health": "healthy"
      }
  """
  def stats(conn, _params) do
    try do
      cache_stats = RouteWiseApi.TileCache.stats()
      rate_limiter_stats = RouteWiseApi.OSMTileClient.rate_limit_stats()
      
      stats = %{
        cache: cache_stats,
        rate_limiter: rate_limiter_stats,
        health: determine_health_status(cache_stats, rate_limiter_stats),
        timestamp: DateTime.utc_now()
      }
      
      json(conn, stats)
    rescue
      error ->
        Logger.error("Error getting tile stats: #{inspect(error)}")
        
        conn
        |> put_status(500)
        |> json(%{
          error: "Unable to retrieve tile statistics",
          health: "degraded"
        })
    end
  end

  @doc """
  Clear the tile cache.
  Useful for development and testing.

  ## Route
      DELETE /api/tiles/cache

  ## Response
      {
        "message": "Tile cache cleared successfully",
        "cleared_at": "2025-08-17T10:30:00Z"
      }
  """
  def clear_cache(conn, _params) do
    case RouteWiseApi.TileCache.clear_cache() do
      :ok ->
        Logger.info("Tile cache cleared via API request")
        
        json(conn, %{
          message: "Tile cache cleared successfully",
          cleared_at: DateTime.utc_now()
        })
      
      {:error, reason} ->
        Logger.error("Failed to clear tile cache: #{inspect(reason)}")
        
        conn
        |> put_status(500)
        |> json(%{
          error: "Failed to clear tile cache",
          details: inspect(reason)
        })
    end
  end

  ## Private Functions

  defp parse_coordinates(z_str, x_str, y_str) do
    try do
      z = String.to_integer(z_str)
      x = String.to_integer(x_str)
      
      # Handle .png extension in y coordinate
      y = case String.ends_with?(y_str, ".png") do
        true -> 
          y_str 
          |> String.replace_suffix(".png", "")
          |> String.to_integer()
        false -> 
          String.to_integer(y_str)
      end
      
      case validate_tile_coordinates(z, x, y) do
        :ok -> {:ok, z, x, y}
        {:error, reason} -> {:error, :invalid_coordinates, reason}
      end
    rescue
      ArgumentError ->
        {:error, :invalid_coordinates, "Coordinates must be integers"}
    end
  end

  defp validate_tile_coordinates(z, x, y) do
    max_coord = trunc(:math.pow(2, z))
    
    cond do
      z < 0 or z > 19 ->
        {:error, "Zoom level must be between 0 and 19"}
      
      x < 0 or x >= max_coord ->
        {:error, "X coordinate must be between 0 and #{max_coord - 1} for zoom level #{z}"}
      
      y < 0 or y >= max_coord ->
        {:error, "Y coordinate must be between 0 and #{max_coord - 1} for zoom level #{z}"}
      
      true ->
        :ok
    end
  end

  defp get_tile_data(z, x, y, params) do
    force_refresh = Map.get(params, "refresh") == "true"
    
    if force_refresh do
      fetch_and_cache_tile(z, x, y)
    else
      case RouteWiseApi.TileCache.get_tile(z, x, y) do
        {:ok, tile_data} ->
          {:ok, tile_data, :hit}
        
        :error ->
          fetch_and_cache_tile(z, x, y)
      end
    end
  end

  defp fetch_and_cache_tile(z, x, y) do
    case RouteWiseApi.OSMTileClient.fetch_tile(z, x, y) do
      {:ok, tile_data} ->
        # Store in cache for future requests
        case RouteWiseApi.TileCache.put_tile(z, x, y, tile_data) do
          :ok ->
            {:ok, tile_data, :miss}
          
          {:error, cache_error} ->
            Logger.warning("Failed to cache tile #{z}/#{x}/#{y}: #{inspect(cache_error)}")
            # Still return the tile data even if caching failed
            {:ok, tile_data, :miss}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_tile_headers(conn, z, x, y, cache_status) do
    etag = generate_etag(z, x, y)
    
    conn
    |> put_resp_header("Cache-Control", "public, max-age=604800, immutable")
    |> put_resp_header("ETag", etag)
    |> put_resp_header("X-Cache-Status", Atom.to_string(cache_status))
    |> put_resp_header("X-Tile-Coordinates", "#{z}/#{x}/#{y}")
    |> put_resp_header("Access-Control-Allow-Origin", "*")
    |> put_resp_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
    |> put_resp_header("Access-Control-Allow-Headers", "Content-Type, Cache-Control")
    |> maybe_add_compression_headers()
  end

  defp generate_etag(z, x, y) do
    # Generate a simple ETag based on coordinates
    # In a production system, you might include a hash of the tile data
    hash = :crypto.hash(:md5, "tile-#{z}-#{x}-#{y}") |> Base.encode16(case: :lower)
    "\"tile-#{String.slice(hash, 0, 8)}\""
  end

  defp maybe_add_compression_headers(conn) do
    # Add compression hint for reverse proxies
    put_resp_header(conn, "Vary", "Accept-Encoding")
  end

  defp determine_health_status(cache_stats, rate_limiter_stats) do
    cond do
      Map.get(cache_stats, :memory_usage, 0) > 0.95 ->
        "degraded"
      
      Map.get(rate_limiter_stats, :rate_limit_percentage, 0) > 20 ->
        "degraded"
      
      true ->
        "healthy"
    end
  end
end