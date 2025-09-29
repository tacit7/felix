defmodule RouteWiseApiWeb.POIJSON do
  import RouteWiseApiWeb.CacheHelpers
  alias RouteWiseApi.Places.Place
  alias RouteWiseApi.POIFormatterService

  @doc """
  Renders a list of POIs.
  """
  def index(%{pois: pois} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: for(poi <- pois, do: data(poi))}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders a single POI.
  """
  def show(%{poi: poi} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: data(poi)}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders POI categories.
  """
  def categories(%{categories: categories} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: categories}
    |> maybe_add_cache_meta(cache_info)
  end

  defp data(%Place{} = place) do
    # Use the POI formatter service for consistent formatting
    POIFormatterService.format_poi_for_response(place)
  end
end