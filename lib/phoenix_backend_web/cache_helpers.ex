defmodule RouteWiseApiWeb.CacheHelpers do
  @moduledoc """
  Helper functions for adding cache metadata to API responses in development.
  
  Provides unified cache status indicators across all API endpoints.
  Cache metadata is only added in development environment for debugging purposes.
  """

  alias RouteWiseApi.Caching

  @doc """
  Conditionally adds cache metadata to API responses in development environment only.
  
  ## Parameters
  - response: The original API response map
  - cache_info: Cache status information (optional)
  
  ## Examples
  
      # In development - adds cache metadata
      iex> maybe_add_cache_meta(%{data: %{name: "Place"}}, {:cache_hit, :memory})
      %{data: %{name: "Place"}, _cache: %{status: "hit", backend: "Memory", environment: "dev"}}
      
      # In production - returns response unchanged
      iex> maybe_add_cache_meta(%{data: %{name: "Place"}}, {:cache_hit, :memory})
      %{data: %{name: "Place"}}
  """
  def maybe_add_cache_meta(response, cache_info \\ nil) do
    if Mix.env() == :dev do
      add_cache_meta(response, cache_info)
    else
      response
    end
  end

  @doc """
  Adds cache metadata to response map.
  
  Cache info can be:
  - {:cache_hit, backend_atom} - Data retrieved from cache
  - {:cache_miss, backend_atom} - Data fetched fresh (not from cache)  
  - :cache_disabled - Cache is disabled
  - nil - No specific cache information available
  """
  def add_cache_meta(response, cache_info) when is_map(response) do
    cache_metadata = build_cache_metadata(cache_info)
    Map.put(response, :_cache, cache_metadata)
  end

  @doc """
  Helper to determine if cache was used based on common service patterns.
  
  Analyzes service function results to infer cache usage.
  """
  def infer_cache_status(service_result, _opts \\ []) do
    case service_result do
      {:ok, _data} ->
        # Default assumption - could be cache hit or miss
        # Services should ideally return explicit cache status
        backend = get_current_backend()
        if backend_enabled?(backend) do
          {:cache_hit, backend}
        else
          :cache_disabled
        end
        
      _ ->
        nil
    end
  end

  # Private functions

  defp build_cache_metadata(cache_info) do
    base_meta = %{
      environment: Atom.to_string(Mix.env()),
      backend: get_backend_name(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case cache_info do
      {:cache_hit, backend} ->
        base_meta
        |> Map.put(:status, "hit")
        |> Map.put(:backend, backend_to_string(backend))

      {:cache_miss, backend} ->
        base_meta
        |> Map.put(:status, "miss")
        |> Map.put(:backend, backend_to_string(backend))

      :cache_disabled ->
        base_meta
        |> Map.put(:status, "disabled")
        |> Map.put(:backend, "Disabled")

      nil ->
        base_meta
        |> Map.put(:status, "unknown")
    end
  end

  defp get_current_backend do
    try do
      Caching.backend()
    rescue
      _ -> nil
    end
  end

  defp get_backend_name do
    case get_current_backend() do
      nil -> "Unknown"
      backend -> backend_to_string(backend)
    end
  end

  defp backend_enabled?(nil), do: false
  defp backend_enabled?(RouteWiseApi.Caching.Backend.Disabled), do: false
  defp backend_enabled?(_), do: true

  defp backend_to_string(nil), do: "Unknown"
  defp backend_to_string(RouteWiseApi.Caching.Backend.Memory), do: "Memory"
  defp backend_to_string(RouteWiseApi.Caching.Backend.Redis), do: "Redis"
  defp backend_to_string(RouteWiseApi.Caching.Backend.Hybrid), do: "Hybrid"
  defp backend_to_string(RouteWiseApi.Caching.Backend.Disabled), do: "Disabled"
  defp backend_to_string(backend) when is_atom(backend) do
    backend
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
  end
  defp backend_to_string(backend), do: inspect(backend)
end