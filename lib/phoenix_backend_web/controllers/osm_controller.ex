defmodule RouteWiseApiWeb.OSMController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.OSMPlaces

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  Search for nearby places using OpenStreetMap data (100% free).
  
  ## Parameters
  - lat: Latitude (required)
  - lng: Longitude (required)
  - radius: Search radius in meters (optional, default: 2000, max: 10000)
  - categories: Comma-separated categories (optional, default: "all")
    - "restaurant" - Restaurants, cafes, bars
    - "accommodation" - Hotels, hostels, B&Bs
    - "attraction" - Tourist attractions, museums
    - "shopping" - Shops, malls, markets
    - "service" - Banks, pharmacies, services
    - "all" - All categories
  - limit: Maximum results (optional, default: 50, max: 100)

  ## Examples
  GET /api/osm/nearby?lat=18.2357&lng=-66.0328&radius=5000&categories=restaurant,attraction&limit=30
  """
  def nearby(conn, params) do
    with {:ok, search_params} <- validate_nearby_params(params),
         {:ok, places} <- OSMPlaces.search_nearby(
           search_params.lat,
           search_params.lng,
           search_params.radius,
           search_params.categories,
           search_params.limit
         ) do
      
      response_data = %{
        places: places,
        count: length(places),
        search_params: %{
          lat: search_params.lat,
          lng: search_params.lng,
          radius: search_params.radius,
          categories: search_params.categories,
          limit: search_params.limit
        },
        data_source: "OpenStreetMap",
        cost: "Free",
        cache_info: determine_cache_status(places)
      }
      
      json(conn, %{
        success: true,
        data: response_data,
        timestamp: DateTime.utc_now()
      })
    end
  end

  @doc """
  Search for places by specific category using OSM data.
  
  ## Parameters
  - lat: Latitude (required)
  - lng: Longitude (required)
  - category: Single category (required)
  - radius: Search radius in meters (optional, default: 2000)
  - limit: Maximum results (optional, default: 30)

  ## Examples
  GET /api/osm/category/restaurant?lat=18.2357&lng=-66.0328&radius=3000
  """
  def category(conn, %{"category" => category} = params) do
    with {:ok, search_params} <- validate_category_params(params, category),
         {:ok, places} <- OSMPlaces.search_by_category(
           search_params.lat,
           search_params.lng,
           search_params.category,
           search_params.radius,
           search_params.limit
         ) do
      
      response_data = %{
        places: places,
        count: length(places),
        category: search_params.category,
        search_params: %{
          lat: search_params.lat,
          lng: search_params.lng,
          radius: search_params.radius,
          limit: search_params.limit
        },
        data_source: "OpenStreetMap",
        cost: "Free"
      }
      
      json(conn, %{
        success: true,
        data: response_data,
        timestamp: DateTime.utc_now()
      })
    end
  end

  @doc """
  Get OSM data coverage statistics for a location.
  Useful for understanding data quality and completeness.
  
  ## Parameters
  - lat: Latitude (required)
  - lng: Longitude (required)
  - radius: Analysis radius in meters (optional, default: 5000)

  ## Examples
  GET /api/osm/coverage?lat=18.2357&lng=-66.0328&radius=10000
  """
  def coverage(conn, params) do
    with {:ok, lat} <- validate_coordinate(params, "lat", -90, 90),
         {:ok, lng} <- validate_coordinate(params, "lng", -180, 180),
         {:ok, radius} <- validate_radius(params) do
      
      stats = OSMPlaces.get_coverage_stats(lat, lng, radius)
      
      json(conn, %{
        success: true,
        data: stats,
        timestamp: DateTime.utc_now()
      })
    end
  end

  # Private validation functions

  defp validate_nearby_params(params) do
    with {:ok, lat} <- validate_coordinate(params, "lat", -90, 90),
         {:ok, lng} <- validate_coordinate(params, "lng", -180, 180),
         {:ok, radius} <- validate_radius(params),
         {:ok, categories} <- validate_categories(params),
         {:ok, limit} <- validate_limit(params) do
      {:ok, %{
        lat: lat,
        lng: lng,
        radius: radius,
        categories: categories,
        limit: limit
      }}
    end
  end

  defp validate_category_params(params, category) do
    valid_categories = ["restaurant", "accommodation", "attraction", "shopping", "service"]
    
    if category in valid_categories do
      with {:ok, lat} <- validate_coordinate(params, "lat", -90, 90),
           {:ok, lng} <- validate_coordinate(params, "lng", -180, 180),
           {:ok, radius} <- validate_radius(params),
           {:ok, limit} <- validate_limit(params) do
        {:ok, %{
          lat: lat,
          lng: lng,
          category: category,
          radius: radius,
          limit: limit
        }}
      end
    else
      {:error, {:bad_request, "Invalid category. Must be one of: #{Enum.join(valid_categories, ", ")}"}}
    end
  end

  defp validate_coordinate(params, key, min_val, max_val) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case Float.parse(value) do
          {float_val, ""} when float_val >= min_val and float_val <= max_val ->
            {:ok, float_val}
          _ ->
            {:error, {:bad_request, "#{key} must be a valid number between #{min_val} and #{max_val}"}}
        end
      value when is_number(value) and value >= min_val and value <= max_val ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "#{key} is required and must be between #{min_val} and #{max_val}"}}
    end
  end

  defp validate_radius(params) do
    case Map.get(params, "radius") do
      nil -> 
        {:ok, 2000}  # Default radius
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_val, ""} when int_val >= 100 and int_val <= 10_000 ->
            {:ok, int_val}
          _ ->
            {:error, {:bad_request, "radius must be between 100 and 10,000 meters"}}
        end
      value when is_integer(value) and value >= 100 and value <= 10_000 ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "radius must be between 100 and 10,000 meters"}}
    end
  end

  defp validate_categories(params) do
    valid_categories = ["restaurant", "accommodation", "attraction", "shopping", "service", "all"]
    
    case Map.get(params, "categories") do
      nil ->
        {:ok, ["all"]}  # Default to all categories
      value when is_binary(value) ->
        categories = value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(fn cat -> cat in valid_categories end)
        
        case categories do
          [] -> {:ok, ["all"]}  # Default if no valid categories
          cats -> {:ok, cats}
        end
      _ ->
        {:ok, ["all"]}
    end
  end

  defp validate_limit(params) do
    case Map.get(params, "limit") do
      nil ->
        {:ok, 50}  # Default limit
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_val, ""} when int_val > 0 and int_val <= 100 ->
            {:ok, int_val}
          _ ->
            {:error, {:bad_request, "limit must be between 1 and 100"}}
        end
      value when is_integer(value) and value > 0 and value <= 100 ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "limit must be between 1 and 100"}}
    end
  end

  defp determine_cache_status(places) do
    cond do
      Enum.empty?(places) ->
        %{status: "no_data", source: "osm"}
        
      Enum.any?(places, fn place -> Map.get(place, :source) == "openstreetmap_cached" end) ->
        %{status: "cache_hit", source: "database"}
        
      true ->
        %{status: "cache_miss", source: "overpass_api"}
    end
  end
end