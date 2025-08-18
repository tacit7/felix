defmodule RouteWiseApi.Caching.Places do
@moduledoc """
Google Places API caching with location-based cache keys.
"""

    alias RouteWiseApi.Caching.Config
    require Logger

    @doc """
    Get cached places search results.
    """
    def get_search_cache(query, location) do
      cache_key = build_search_key(query, location)
      backend = Config.backend()

      backend.get(cache_key)
    end

    @doc """
    Cache places search results.
    """
    def put_search_cache(query, location, results) do
      cache_key = build_search_key(query, location)
      ttl = Config.ttl(:medium)  # 15 minutes for search results
      backend = Config.backend()

      backend.put(cache_key, results, ttl)
    end

    @doc """
    Get cached place details.
    """
    def get_details_cache(place_id) do
      cache_key = "places:details:#{place_id}"
      backend = Config.backend()

      backend.get(cache_key)
    end

    @doc """
    Cache place details with long TTL (place details rarely change).
    """
    def put_details_cache(place_id, details) do
      cache_key = "places:details:#{place_id}"
      ttl = Config.ttl(:daily)  # 24 hours for place details
      backend = Config.backend()

      backend.put(cache_key, details, ttl)
    end

    # Private functions

    defp build_search_key(query, %{lat: lat, lng: lng}) do
      # Create a stable cache key from query and rounded location
      rounded_lat = Float.round(lat, 3)  # ~100m precision
      rounded_lng = Float.round(lng, 3)
      query_hash = :crypto.hash(:md5, query) |> Base.encode16()

      "places:search:#{query_hash}:#{rounded_lat}:#{rounded_lng}"
    end

    defp build_search_key(query, location) when is_binary(location) do
      query_hash = :crypto.hash(:md5, query) |> Base.encode16()
      location_hash = :crypto.hash(:md5, location) |> Base.encode16()

      "places:search:#{query_hash}:#{location_hash}"
    end

end
