defmodule RouteWiseApiWeb.ExploreResultsController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.{LocationDisambiguation, LocationDataService, POIProcessingService, 
                      CachedPlaceService, ResponseBuilder}

  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert

  @doc """
  Consolidated endpoint that returns all data needed for explore results page:
  - POIs near location (from database/Google or OSM)
  - Geocoded coordinates for location
  - Google Maps API key
  - Metadata
  
  ## Parameters
  - location: Location to search (required if place_id not provided)
  - place_id: UUID from cached_places table (required if location not provided)
  - source: Data source - "auto" (default), "google", "osm"
  - radius: Search radius in meters (optional, default: 5000)
  - categories: Comma-separated categories for OSM search (optional)
  
  ## Examples
  GET /api/explore-results?location=Austin&source=auto
  GET /api/explore-results?place_id=550e8400-e29b-41d4-a716-446655440000&source=auto
  GET /api/explore-results?location=Puerto%20Rico&source=osm&radius=10000&categories=restaurant,attraction
  """
  def index(conn, %{"place_id" => place_id} = params) do
    pre!(is_binary(place_id) and byte_size(place_id) > 0, "place_id must be non-empty string")
    pre!(is_map(params), "params must be a map")
    
    try do
      # Look up place in cached_places table
      case CachedPlaceService.get_cached_place_by_id(place_id) do
        {:ok, cached_place} ->
          Logger.info("🎯 Using cached place: #{cached_place.name} (#{cached_place.lat}, #{cached_place.lon})")
          
          # Increment search count for this place
          CachedPlaceService.increment_cached_place_usage(cached_place)
          
          # Build location data and fetch POIs
          location_data = LocationDataService.build_cached_place_location_data(cached_place)
          pois = POIProcessingService.process_pois_for_cached_place(cached_place, params)
          formatted_pois = POIProcessingService.format_and_log_pois(pois, cached_place.name)
          
          # Build response with cached place metadata
          cached_place_meta = CachedPlaceService.build_cached_place_metadata(place_id, cached_place)
          response = ResponseBuilder.build_explore_response(pois, formatted_pois, cached_place.name, location_data, cached_place_meta)
          json(conn, response)
          
        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(ResponseBuilder.build_place_not_found_error(place_id))
      end
      
    rescue
      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(ResponseBuilder.build_internal_server_error("fetch explore results", error))
    end
  end

  def index(conn, %{"location" => location} = params) do
    pre!(is_binary(location) and byte_size(location) > 0, "location must be non-empty string")
    pre!(is_map(params), "params must be a map")
    
    try do
      # Geocode location with bounds (with caching)
      location_data = LocationDataService.fetch_location_with_bounds_cached(location)
      
      # Fetch and format POIs
      pois = POIProcessingService.process_pois_for_location(location, params)
      formatted_pois = POIProcessingService.format_and_log_pois(pois, location)
      
      # Build response (no additional metadata for location searches)
      response = ResponseBuilder.build_explore_response(pois, formatted_pois, location, location_data, %{})
      json(conn, response)
      
    rescue
      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(ResponseBuilder.build_internal_server_error("fetch explore results", error))
    end
  end

  # Handle missing parameters
  def index(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(ResponseBuilder.build_missing_parameter_error(%{
      name: "location or place_id", 
      message: "Either 'location' or 'place_id' query parameter is required"
    }))
  end

  @doc """
  Location disambiguation endpoint.
  Returns suggestions when location queries are ambiguous.
  
  GET /api/explore-results/disambiguate?location=Ponce
  """
  def disambiguate(conn, %{"location" => location}) do
    pre!(is_binary(location) and byte_size(location) > 0, "location must be non-empty string")
    
    try do
      case LocationDisambiguation.get_suggestions(location) do
        {:ok, suggestions} ->
          assert!(is_list(suggestions), "suggestions must be a list")
          post!(length(suggestions) >= 0, "suggestions count must be non-negative")
          
          json(conn, ResponseBuilder.build_disambiguation_response(location, suggestions))
        
        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(ResponseBuilder.build_disambiguation_error(reason))
      end
    rescue
      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(ResponseBuilder.build_internal_server_error("disambiguate location", error))
    end
  end

  def disambiguate(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(ResponseBuilder.build_missing_parameter_error(%{
      name: "location", 
      message: "The 'location' query parameter is required"
    }))
  end

  # All business logic now handled by dedicated service modules
end