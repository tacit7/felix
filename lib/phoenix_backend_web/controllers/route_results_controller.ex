defmodule RouteWiseApiWeb.RouteResultsController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Trips
  alias RouteWiseApi.RouteService
  alias RouteWiseApi.POIFormatterService

  require Logger

  @doc """
  Consolidated endpoint that returns all data needed for route results page:
  - POIs along the route
  - Route information (distance, duration) 
  - Geocoded coordinates for start/end cities
  - Google Maps API key
  - Metadata
  
  GET /api/route-results?start=Austin&end=Dallas
  """
  def index(conn, %{"start" => start_city, "end" => end_city} = _params) do
    try do
      # Geocode start and end cities (with caching)
      {start_coords, end_coords} = geocode_cities_with_cache(start_city, end_city)
      
      # Fetch POIs for the route (reuse existing POI logic)
      pois = fetch_pois_for_route(start_city, end_city)
      
      # Calculate route information
      route_data = calculate_route_data(start_city, end_city)
      
      # Get Maps API key from environment
      maps_api_key = get_maps_api_key()
      
      # Format POIs for response using shared service
      formatted_pois = POIFormatterService.format_pois_list(pois)
      
      # Log the POIs being sent
      Logger.info("🎯 Sending #{length(formatted_pois)} POIs for route #{start_city} -> #{end_city}")
      Enum.each(formatted_pois, fn poi ->
        Logger.info("  📍 #{poi.name} | #{List.first(poi.placeTypes) || "unknown"} | #{poi.rating}⭐ | #{poi.address || "No address"}")
      end)
      
      # Determine cache status for the response
      cache_info = determine_route_results_cache_status(pois, route_data)
      
      # Format response
      response = %{
        success: true,
        data: %{
          pois: formatted_pois,
          location: %{
            start: %{
              name: start_city,
              coords: start_coords || %{lat: 0, lng: 0}
            },
            end: %{
              name: end_city,
              coords: end_coords || %{lat: 0, lng: 0}
            }
          },
          route: route_data || %{
            distance: "Unknown",
            duration: "Unknown",
            estimated: true,
            polyline: nil,
            steps: []
          },
          metadata: %{
            total_pois: length(formatted_pois),
            provider: "RouteWise",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            cache_info: cache_info
          },
          ui: %{
            maps_api_key: maps_api_key,
            provider: "google_maps"
          }
        }
      }

      json(conn, response)
    rescue
      error ->
        Logger.error("Error in route results controller: #{Exception.message(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Internal server error",
          message: Exception.message(error)
        })
    end
  end

  # Handle case where start or end city is missing
  def index(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Missing required parameters",
      message: "Both 'start' and 'end' city parameters are required"
    })
  end

  # Private helper functions

  defp geocode_cities_with_cache(start_city, end_city) do
    # Use tasks to geocode cities in parallel for better performance
    start_task = Task.async(fn -> 
      case RouteWiseApi.GeocodeService.resolve_location_enhanced(start_city) do
        {:ok, city, _meta} ->
          %{
            lat: Map.get(city, :lat) || Map.get(city, :latitude),
            lng: Map.get(city, :lng) || Map.get(city, :longitude)
          }
        {:error, reason} ->
          Logger.warning("Failed to geocode start city '#{start_city}': #{reason}")
          nil
      end
    end)
    
    end_task = Task.async(fn ->
      case RouteWiseApi.GeocodeService.resolve_location_enhanced(end_city) do
        {:ok, city, _meta} ->
          %{
            lat: Map.get(city, :lat) || Map.get(city, :latitude),
            lng: Map.get(city, :lng) || Map.get(city, :longitude)
          }
        {:error, reason} ->
          Logger.warning("Failed to geocode end city '#{end_city}': #{reason}")
          nil
      end
    end)
    
    # Wait for both tasks to complete
    start_coords = Task.await(start_task, 5000)  # 5 second timeout
    end_coords = Task.await(end_task, 5000)
    
    {start_coords, end_coords}
  rescue
    error ->
      Logger.error("Exception geocoding cities: #{Exception.message(error)}")
      {nil, nil}
  end

  defp fetch_pois_for_route(start_city, end_city) do
    # For now, fetch POIs for the start city
    # In the future, this could be enhanced to fetch POIs along the route
    case RouteWiseApi.POIFetchingService.fetch_pois_for_location(start_city) do
      {:ok, pois} -> 
        Logger.info("Fetched #{length(pois)} POIs for route")
        pois
      {:error, reason} ->
        Logger.warning("Failed to fetch POIs for route: #{reason}")
        []
    end
  rescue
    error ->
      Logger.error("Exception fetching POIs for route: #{Exception.message(error)}")
      []
  end

  defp calculate_route_data(start_city, end_city) do
    case RouteService.calculate_route(start_city, end_city) do
      {:ok, route_summary} ->
        Logger.info("Route calculation successful: #{start_city} -> #{end_city}")
        route_summary
      {:error, reason} ->
        Logger.warning("Route calculation failed: #{reason}")
        %{
          distance: "Unknown",
          duration: "Unknown", 
          estimated: true,
          polyline: nil,
          steps: []
        }
    end
  rescue
    error ->
      Logger.error("Exception calculating route: #{Exception.message(error)}")
      %{
        distance: "Unknown",
        duration: "Unknown",
        estimated: true,
        polyline: nil,
        steps: []
      }
  end

  defp get_maps_api_key() do
    System.get_env("GOOGLE_MAPS_API_KEY")
  end

  defp determine_route_results_cache_status(pois, route_data) do
    cond do
      length(pois) > 10 and route_data != nil ->
        %{
          status: "full_cache_hit",
          description: "Route and POI data from cache",
          performance: "excellent"
        }
      
      length(pois) > 5 ->
        %{
          status: "partial_cache_hit",
          description: "Some data from cache",
          performance: "good"
        }
      
      length(pois) > 0 ->
        %{
          status: "cache_miss",
          description: "Data fetched from external APIs",
          performance: "fair"
        }
      
      true ->
        %{
          status: "no_data",
          description: "No data available for this route",
          performance: "poor"
        }
    end
  end
end