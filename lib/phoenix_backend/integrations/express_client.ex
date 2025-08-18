defmodule RouteWiseApi.Integrations.ExpressClient do
  @moduledoc """
  HTTP client for communicating with Express.js user interests service.
  Handles connection pooling, timeouts, and error recovery.
  """

  require Logger

  @base_url Application.compile_env(:phoenix_backend, :express_base_url, "http://localhost:3001/api")
  @timeout 5_000
  @max_retries 2
  @cache_ttl 15 * 60 * 1000  # 15 minutes

  alias RouteWiseApi.Cache

  @doc """
  Get all interest categories from Express.js service
  """
  def get_interest_categories do
    cache_key = "express:categories"
    
    case Cache.get(cache_key) do
      {:ok, cached_data} -> 
        {:ok, cached_data}
      _ ->
        case make_request("GET", "/interests/categories") do
          {:ok, categories} ->
            Cache.put(cache_key, categories, @cache_ttl)
            {:ok, categories}
          error -> error
        end
    end
  end

  @doc """
  Get user interests from Express.js service
  """
  def get_user_interests(user_id, auth_token) when is_integer(user_id) do
    cache_key = "express:user_interests:#{user_id}"
    
    case Cache.get(cache_key) do
      {:ok, cached_data} -> 
        {:ok, cached_data}
      _ ->
        headers = auth_headers(auth_token)
        case make_request("GET", "/users/#{user_id}/interests", nil, headers) do
          {:ok, interests} ->
            Cache.put(cache_key, interests, @cache_ttl)
            {:ok, interests}
          error -> error
        end
    end
  end

  @doc """
  Get suggested trips from Express.js service
  """
  def get_suggested_trips(auth_token, limit \\ 5) do
    headers = auth_headers(auth_token)
    query_params = "?limit=#{limit}"
    make_request("GET", "/trips/suggested#{query_params}", nil, headers)
  end

  @doc """
  Update user interests via Express.js service
  """
  def update_user_interests(user_id, interests_data, auth_token) when is_integer(user_id) do
    headers = auth_headers(auth_token)
    body = Jason.encode!(interests_data)
    
    case make_request("PUT", "/users/#{user_id}/interests", body, headers) do
      {:ok, updated_interests} ->
        # Invalidate cache
        cache_key = "express:user_interests:#{user_id}"
        Cache.delete(cache_key)
        {:ok, updated_interests}
      error -> error
    end
  end

  @doc """
  Health check for Express.js service
  """
  def health_check do
    case make_request("GET", "/health", nil, [], 2_000) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  # Private functions

  defp make_request(method, path, body \\ nil, headers \\ [], timeout \\ @timeout) do
    url = @base_url <> path
    headers = [{"content-type", "application/json"} | headers]
    
    request_options = [
      timeout: timeout,
      recv_timeout: timeout,
      follow_redirects: true
    ]

    perform_request_with_retry(method, url, body, headers, request_options, @max_retries)
  end

  defp perform_request_with_retry(method, url, body, headers, options, retries_left) do
    case HTTPoison.request(String.downcase(method), url, body || "", headers, options) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} 
        when status_code in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, :json_decode_error}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.warning("Express.js API error: #{status_code} - #{response_body}")
        {:error, {:http_error, status_code, response_body}}

      {:error, %HTTPoison.Error{reason: reason}} when retries_left > 0 ->
        Logger.warning("Express.js API request failed, retrying: #{inspect(reason)}")
        :timer.sleep(backoff_delay(@max_retries - retries_left))
        perform_request_with_retry(method, url, body, headers, options, retries_left - 1)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Express.js API request failed after retries: #{inspect(reason)}")
        {:error, {:network_error, reason}}
    end
  end

  defp auth_headers(nil), do: []
  defp auth_headers(token), do: [{"authorization", "Bearer #{token}"}]

  defp backoff_delay(attempt) do
    # Exponential backoff: 100ms, 200ms, 400ms
    trunc(100 * :math.pow(2, attempt))
  end
end