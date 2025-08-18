defmodule RouteWiseApi.Caching.Backend.Disabled do
  @moduledoc """
  Disabled cache backend that provides no-op caching for debugging.
  
  All cache operations return cache misses, effectively disabling 
  all caching while maintaining API compatibility.
  """
  
  @behaviour RouteWiseApi.Caching.Backend
  
  @impl true
  def get(_key), do: :error
  
  @impl true  
  def put(_key, _value, _ttl_ms), do: :ok
  
  @impl true
  def delete(_key), do: :ok
  
  @impl true
  def clear(), do: :ok
  
  @impl true
  def stats() do
    %{
      backend: "disabled",
      status: "disabled",
      hit_rate: 0.0,
      total_requests: 0,
      cache_hits: 0,
      cache_misses: 0
    }
  end
  
  @impl true
  def health_check(), do: :ok
  
  @impl true
  def invalidate_pattern(_pattern), do: :ok
end