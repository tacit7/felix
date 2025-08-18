defmodule RouteWiseApi.Caching.Trips do
@moduledoc """
Trip data caching for public and user-specific trips.
"""

    alias RouteWiseApi.Caching.Config
    require Logger

    @doc """
    Get cached public trips.
    """
    def get_public_cache do
      backend = Config.backend()
      backend.get("trips:public")
    end

    @doc """
    Cache public trips data.
    """
    def put_public_cache(trips) do
      ttl = Config.ttl(:long)  # 1 hour for public trips
      backend = Config.backend()

      backend.put("trips:public", trips, ttl)
    end

    @doc """
    Get cached user trips.
    """
    def get_user_cache(user_id) do
      cache_key = "trips:user:#{user_id}"
      backend = Config.backend()

      backend.get(cache_key)
    end

    @doc """
    Cache user trips data.
    """
    def put_user_cache(user_id, trips) do
      cache_key = "trips:user:#{user_id}"
      ttl = Config.ttl(:medium)  # 15 minutes for user trips
      backend = Config.backend()

      backend.put(cache_key, trips, ttl)
    end

    @doc """
    Invalidate user trips cache.
    """
    def invalidate_user_cache(user_id) do
      cache_key = "trips:user:#{user_id}"
      backend = Config.backend()

      backend.delete(cache_key)
    end

end
