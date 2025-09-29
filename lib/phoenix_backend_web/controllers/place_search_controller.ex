defmodule RouteWiseApiWeb.PlaceSearchController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.PlaceSearch
  require Logger

  @doc """
  Search for places using the enhanced search system with aliases.

  ## Parameters
  - `q` (required): Search query (minimum 2 characters)
  - `limit` (optional): Maximum results (1-100, default 10)
  - `threshold` (optional): Similarity threshold (0.0-1.0, default from config)

  ## Response Format
  ```json
  {
    "query": "USVI",
    "results": [
      {
        "id": 123,
        "label": "United States Virgin Islands",
        "kind": "region",
        "score": 0.98,
        "code": "USVI",
        "coordinates": {"lat": 17.789187, "lng": -64.708057},
        "popularity": 85,
        "metadata": {"country": "United States", "region": "Caribbean"},
        "matched_via": "USVI",
        "match_type": "exact_alias"
      }
    ],
    "stats": {
      "total_results": 1,
      "search_time_ms": 12,
      "match_types_found": ["exact_alias"],
      "cache_status": "miss"
    }
  }
  ```

  ## Status Codes
  - `200` - Success with results
  - `422` - Invalid parameters (missing query, query too short)
  - `429` - Rate limit exceeded
  - `500` - Internal server error
  """
  def search(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, query} <- extract_query(params),
         {:ok, limit} <- extract_limit(params),
         {:ok, threshold} <- extract_threshold(params),
         :ok <- check_rate_limit(conn),
         {:ok, results} <- PlaceSearch.search(query, limit: limit, threshold: threshold) do

      end_time = System.monotonic_time(:millisecond)
      search_time_ms = end_time - start_time

      response = %{
        query: query,
        results: format_results_for_api(results),
        stats: %{
          total_results: length(results),
          search_time_ms: search_time_ms,
          match_types_found: get_unique_match_types(results),
          cache_status: "miss"  # TODO: Implement caching in future iteration
        }
      }

      # Log successful search for curation
      log_search_success(query, length(results), search_time_ms, conn)

      json(conn, response)
    else
      {:error, :rate_limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "rate_limit_exceeded",
          message: "Too many requests. Please try again later.",
          retry_after_seconds: 60
        })

      {:error, :invalid_query} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "invalid_query",
          message: "Query parameter 'q' is required and must be at least 2 characters long"
        })

      {:error, :invalid_limit} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "invalid_limit",
          message: "Limit parameter must be between 1 and 100"
        })

      {:error, :invalid_threshold} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "invalid_threshold",
          message: "Threshold parameter must be between 0.0 and 1.0"
        })

      {:error, reason} when is_binary(reason) ->
        # Log search failure for debugging
        log_search_failure(Map.get(params, "q"), reason, conn)

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "search_failed",
          message: "Search operation failed"
        })

      error ->
        Logger.error("Unexpected error in place search: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "internal_error",
          message: "An unexpected error occurred"
        })
    end
  end

  @doc """
  Get search statistics and system information.

  Returns information about the search system including place counts,
  alias counts, and current configuration.
  """
  def stats(conn, _params) do
    stats = PlaceSearch.search_stats()

    json(conn, %{
      system: %{
        places_count: stats.places_count,
        aliases_count: stats.aliases_count,
        current_threshold: stats.current_threshold,
        default_threshold: stats.default_threshold,
        supported_match_types: stats.supported_match_types
      },
      version: "1.0.0",
      last_updated: DateTime.utc_now()
    })
  end

  # Private helper functions

  @spec extract_query(map()) :: {:ok, String.t()} | {:error, :invalid_query}
  defp extract_query(params) do
    case Map.get(params, "q") do
      query when is_binary(query) ->
        trimmed = String.trim(query)
        if String.length(trimmed) >= 2 do
          {:ok, trimmed}
        else
          {:error, :invalid_query}
        end

      _ ->
        {:error, :invalid_query}
    end
  end

  @spec extract_limit(map()) :: {:ok, integer()} | {:error, :invalid_limit}
  defp extract_limit(params) do
    case Map.get(params, "limit") do
      nil ->
        {:ok, 10}

      limit_str when is_binary(limit_str) ->
        case Integer.parse(limit_str) do
          {limit, ""} when limit >= 1 and limit <= 100 ->
            {:ok, limit}
          _ ->
            {:error, :invalid_limit}
        end

      limit when is_integer(limit) and limit >= 1 and limit <= 100 ->
        {:ok, limit}

      _ ->
        {:error, :invalid_limit}
    end
  end

  @spec extract_threshold(map()) :: {:ok, float() | nil} | {:error, :invalid_threshold}
  defp extract_threshold(params) do
    case Map.get(params, "threshold") do
      nil ->
        {:ok, nil}

      threshold_str when is_binary(threshold_str) ->
        case Float.parse(threshold_str) do
          {threshold, ""} when threshold >= 0.0 and threshold <= 1.0 ->
            {:ok, threshold}
          _ ->
            {:error, :invalid_threshold}
        end

      threshold when is_float(threshold) and threshold >= 0.0 and threshold <= 1.0 ->
        {:ok, threshold}

      _ ->
        {:error, :invalid_threshold}
    end
  end

  @spec check_rate_limit(Plug.Conn.t()) :: :ok | {:error, :rate_limit}
  defp check_rate_limit(conn) do
    # Simple IP-based rate limiting
    # In production, this would use a more sophisticated rate limiter
    ip = get_client_ip(conn)
    rate_limit_key = "place_search_rate_limit:#{ip}"

    # TODO: Implement proper rate limiting with Redis or ETS
    # For now, just allow all requests
    :ok
  end

  @spec format_results_for_api([map()]) :: [map()]
  defp format_results_for_api(results) do
    Enum.map(results, fn result ->
      %{
        id: result.place_id,
        label: result.name,
        kind: result.kind,
        score: result.similarity_score,
        code: result.code,
        coordinates: result.coordinates,
        popularity: result.popularity,
        metadata: result.metadata,
        matched_via: result.matched_alias,
        match_type: result.match_type
      }
    end)
  end

  @spec get_unique_match_types([map()]) :: [String.t()]
  defp get_unique_match_types(results) do
    results
    |> Enum.map(& &1.match_type)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec get_client_ip(Plug.Conn.t()) :: String.t()
  defp get_client_ip(conn) do
    # Get real IP from X-Forwarded-For header or remote_ip
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet_parse.ntoa()
        |> to_string()
    end
  end

  @spec log_search_success(String.t(), integer(), integer(), Plug.Conn.t()) :: :ok
  defp log_search_success(query, result_count, search_time_ms, conn) do
    ip_hash = :crypto.hash(:sha256, get_client_ip(conn)) |> Base.encode16() |> String.slice(0..15)

    Logger.info("✅ Place search success",
      query: query,
      result_count: result_count,
      search_time_ms: search_time_ms,
      ip_hash: ip_hash
    )

    # Log to database for curation analysis (Step 6 of POA)
    # TODO: Implement place_query_log table and logging
    :ok
  end

  @spec log_search_failure(String.t() | nil, String.t(), Plug.Conn.t()) :: :ok
  defp log_search_failure(query, reason, conn) do
    ip_hash = :crypto.hash(:sha256, get_client_ip(conn)) |> Base.encode16() |> String.slice(0..15)

    Logger.warning("❌ Place search failure",
      query: query,
      reason: reason,
      ip_hash: ip_hash
    )

    # Log misses for curation (Step 6 of POA)
    # TODO: Implement place_query_log table for missed queries
    :ok
  end
end