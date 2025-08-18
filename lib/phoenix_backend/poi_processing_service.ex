defmodule RouteWiseApi.POIProcessingService do
  @moduledoc """
  Service for processing POI data through fetch and format pipeline.
  
  Handles:
  - POI fetching for cached places
  - POI fetching for locations  
  - POI formatting and validation
  - Error handling and fallback empty results
  """
  
  alias RouteWiseApi.{POIFetchingService, POIFormatterService}
  
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  @doc """
  Fetch and format POIs for a cached place.
  """
  def process_pois_for_cached_place(cached_place, params) do
    pois = case POIFetchingService.fetch_pois_for_cached_place(cached_place, params) do
      {:ok, fetched_pois} -> fetched_pois
      {:error, _reason} -> []
    end
    assert!(is_list(pois), "fetch_pois_for_cached_place must return a list")
    
    format_pois(pois)
  end

  @doc """
  Fetch and format POIs for a location.
  """
  def process_pois_for_location(location, params) do
    pois = case POIFetchingService.fetch_pois_for_location(location, params) do
      {:ok, fetched_pois} -> fetched_pois
      {:error, _reason} -> []
    end
    assert!(is_list(pois), "fetch_pois_for_location must return a list")
    
    format_pois(pois)
  end

  @doc """
  Format POIs using the formatter service and log details.
  """
  def format_and_log_pois(pois, location_name) do
    formatted_pois = format_pois(pois)
    
    # Log the POIs being sent
    Logger.info("🎯 Sending #{length(formatted_pois)} POIs for #{location_name}")
    log_poi_details(formatted_pois)
    
    formatted_pois
  end

  # Private helper functions

  defp format_pois(pois) when is_list(pois) do
    POIFormatterService.format_pois_list(pois)
  end
  
  defp format_pois(_), do: []

  defp log_poi_details(formatted_pois) do
    Enum.each(formatted_pois, fn poi ->
      Logger.info("  📍 #{poi.name} | #{List.first(poi.placeTypes) || "unknown"} | #{poi.rating}⭐ | #{poi.address || "No address"}")
    end)
  end
end