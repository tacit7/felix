defmodule RouteWiseApi.CachedPlaceService do
  @moduledoc """
  Service for handling cached place operations.
  
  Handles:
  - Cached place lookup and retrieval
  - Search count increment and usage tracking
  - Cached place validation
  """
  
  require Logger
  
  @doc """
  Get a cached place by its ID.
  """
  def get_cached_place_by_id(place_id) do
    case RouteWiseApi.Repo.get(RouteWiseApi.Places.CachedPlace, place_id) do
      nil -> {:error, :not_found}
      cached_place -> {:ok, cached_place}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @doc """
  Increment the search count for a cached place.
  """
  def increment_cached_place_usage(cached_place) do
    try do
      cached_place
      |> RouteWiseApi.Places.CachedPlace.increment_search_changeset()
      |> RouteWiseApi.Repo.update()
    rescue
      _ -> :ok  # Don't fail if we can't increment usage
    end
  end

  @doc """
  Build metadata for cached place responses.
  """
  def build_cached_place_metadata(place_id, cached_place) do
    %{
      place_id: place_id,
      place_type: cached_place.place_type,
      from_cache: true
    }
  end
end