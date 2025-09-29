defmodule RouteWiseApiWeb.POIController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Trips
  alias RouteWiseApi.Trips.POI

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  GET /api/pois
  List all POIs or filter by category.
  
  ## Parameters
  - category: Filter POIs by category (optional)
  
  ## Examples
  GET /api/pois
  GET /api/pois?category=restaurant
  """
  def index(conn, %{"category" => category}) when is_binary(category) do
    pois = Trips.list_pois_by_category(category)
    cache_info = determine_poi_cache_status(pois, :category)
    render(conn, :index, pois: pois, cache_info: cache_info)
  end

  def index(conn, _params) do
    pois = Trips.list_pois()
    cache_info = determine_poi_cache_status(pois, :all)
    render(conn, :index, pois: pois, cache_info: cache_info)
  end

  @doc """
  GET /api/pois/:id
  Get a specific POI by ID.
  
  ## Parameters
  - id: POI ID (required)
  
  ## Examples
  GET /api/pois/123
  """
  def nearby(conn, params) do
    # Landing page POI discovery for anonymous users
    with {:ok, location} <- extract_location(params),
         {:ok, pois} <- get_nearby_pois(location, params) do
      cache_info = determine_poi_cache_status(pois, :nearby)
      render(conn, :index, pois: pois, cache_info: cache_info)
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  @doc """
  GET /api/pois/clusters
  Get clustered POIs for a viewport - optimized for anonymous users.
  
  ## Parameters
  - north, south, east, west: Viewport bounds (required)
  - zoom: Zoom level 1-20 (optional, default: 12)
  - categories: Comma-separated list of categories (optional)
  - min_rating: Minimum rating filter (optional)
  
  ## Examples
  GET /api/pois/clusters?north=30.33&south=30.27&east=-97.74&west=-97.77&zoom=12
  GET /api/pois/clusters?north=30.33&south=30.27&east=-97.74&west=-97.77&categories=restaurant,food&min_rating=4.0
  """
  def clusters(conn, params) do
    with {:ok, viewport_bounds} <- extract_viewport_bounds(params),
         {:ok, zoom_level} <- extract_zoom_level(params),
         {:ok, filters} <- extract_cluster_filters(params),
         {:ok, clusters} <- get_clustered_pois(viewport_bounds, zoom_level, filters) do
      
      cache_info = determine_cluster_cache_status(clusters, :viewport)
      
      json(conn, %{
        data: %{
          clusters: clusters,
          viewport: viewport_bounds,
          zoom: zoom_level,
          filters: filters,
          cluster_count: length(clusters),
          poi_count: Enum.sum(Enum.map(clusters, & &1.count))
        },
        _cache: cache_info
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def show(conn, %{"id" => id}) do
    poi = Trips.get_poi!(id)
    cache_info = determine_poi_cache_status([poi], :single)
    render(conn, :show, poi: poi, cache_info: cache_info)
  end

  @doc """
  POST /api/pois
  Create a new POI.
  
  ## Parameters
  - poi: POI attributes (required)
  
  ## Examples
  POST /api/pois
  {
    "poi": {
      "name": "Golden Gate Bridge",
      "description": "Famous suspension bridge",
      "category": "attraction",
      "rating": 4.5,
      "review_count": 1000,
      "time_from_start": "2 hours",
      "image_url": "https://example.com/image.jpg",
      "place_id": "ChIJ...",
      "address": "Golden Gate Bridge, San Francisco, CA",
      "price_level": 0,
      "is_open": true
    }
  }
  """
  def create(conn, %{"poi" => poi_params}) do
    with {:ok, %POI{} = poi} <- Trips.create_poi(poi_params) do
      cache_info = {:cache_miss, :database}  # New POI creation
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/pois/#{poi}")
      |> render(:show, poi: poi, cache_info: cache_info)
    end
  end

  @doc """
  PUT /api/pois/:id
  Update an existing POI.
  
  ## Parameters
  - id: POI ID (required)
  - poi: POI attributes to update (required)
  
  ## Examples
  PUT /api/pois/123
  {
    "poi": {
      "name": "Updated POI Name",
      "rating": 4.8
    }
  }
  """
  def update(conn, %{"id" => id, "poi" => poi_params}) do
    poi = Trips.get_poi!(id)

    with {:ok, %POI{} = poi} <- Trips.update_poi(poi, poi_params) do
      cache_info = {:cache_miss, :database}  # Updated POI
      render(conn, :show, poi: poi, cache_info: cache_info)
    end
  end

  @doc """
  DELETE /api/pois/:id
  Delete a POI.
  
  ## Parameters
  - id: POI ID (required)
  
  ## Examples
  DELETE /api/pois/123
  """
  def delete(conn, %{"id" => id}) do
    poi = Trips.get_poi!(id)

    with {:ok, %POI{}} <- Trips.delete_poi(poi) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  GET /api/pois/bounds
  Get POIs within map bounds (without clustering).

  ## Parameters
  - north, south, east, west: Map bounds (required)
  - categories: Comma-separated list of categories (optional)
  - min_rating: Minimum rating filter (optional)
  - limit: Maximum number of POIs to return (optional, default: 100)

  ## Examples
  GET /api/pois/bounds?north=30.33&south=30.27&east=-97.74&west=-97.77
  GET /api/pois/bounds?north=30.33&south=30.27&east=-97.74&west=-97.77&categories=restaurant,food&min_rating=4.0&limit=50
  """
  def bounds(conn, params) do
    with {:ok, viewport_bounds} <- extract_viewport_bounds(params),
         {:ok, filters} <- extract_bounds_filters(params),
         {:ok, pois} <- get_pois_in_bounds(viewport_bounds, filters) do

      cache_info = determine_bounds_cache_status(pois, :viewport)

      # Format POIs for response using POIFormatterService
      formatted_pois = Enum.map(pois, &RouteWiseApi.POIFormatterService.format_poi_for_response/1)

      json(conn, %{
        data: %{
          pois: formatted_pois,
          bounds: viewport_bounds,
          filters: filters,
          count: length(pois)
        },
        cache: cache_info
      })
    else
      {:error, :invalid_bounds} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid viewport bounds. All bounds parameters (north, south, east, west) are required."})

      {:error, :invalid_filters} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid filter parameters."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch POIs: #{reason}"})
    end
  end

  @doc """
  GET /api/pois/categories
  Get available POI categories.

  ## Examples
  GET /api/pois/categories
  """
  def categories(conn, _params) do
    categories = POI.categories()
    cache_info = {:cache_hit, :static}  # Categories are static data
    render(conn, :categories, categories: categories, cache_info: cache_info)
  end

  # Helper functions for POI clustering endpoint

  defp extract_viewport_bounds(%{"north" => n, "south" => s, "east" => e, "west" => w}) do
    with {n_float, ""} <- Float.parse(to_string(n)),
         {s_float, ""} <- Float.parse(to_string(s)),
         {e_float, ""} <- Float.parse(to_string(e)),
         {w_float, ""} <- Float.parse(to_string(w)) do
      
      if n_float > s_float and e_float > w_float and 
         n_float >= -90 and n_float <= 90 and s_float >= -90 and s_float <= 90 and
         e_float >= -180 and e_float <= 180 and w_float >= -180 and w_float <= 180 do
        {:ok, %{north: n_float, south: s_float, east: e_float, west: w_float}}
      else
        {:error, "Invalid viewport bounds"}
      end
    else
      _ -> {:error, "Invalid coordinate format"}
    end
  end

  defp extract_viewport_bounds(_params) do
    {:error, "Missing required viewport bounds: north, south, east, west"}
  end

  defp extract_zoom_level(%{"zoom" => zoom}) do
    case Integer.parse(to_string(zoom)) do
      {zoom_int, ""} when zoom_int >= 1 and zoom_int <= 20 -> {:ok, zoom_int}
      _ -> {:error, "Invalid zoom level (must be 1-20)"}
    end
  end

  defp extract_zoom_level(_params), do: {:ok, 12}  # Default zoom

  defp extract_cluster_filters(params) do
    filters = %{}
    
    # Parse categories
    filters = case params["categories"] do
      nil -> filters
      "" -> filters
      categories when is_binary(categories) ->
        category_list = String.split(categories, ",") |> Enum.map(&String.trim/1)
        Map.put(filters, :categories, category_list)
      _ -> filters
    end
    
    # Parse min_rating
    filters = case params["min_rating"] do
      nil -> filters
      rating_str when is_binary(rating_str) ->
        case Float.parse(rating_str) do
          {rating, ""} when rating >= 0 and rating <= 5 ->
            Map.put(filters, :min_rating, rating)
          _ -> filters
        end
      rating when is_number(rating) and rating >= 0 and rating <= 5 ->
        Map.put(filters, :min_rating, rating)
      _ -> filters
    end
    
    {:ok, filters}
  end

  defp get_clustered_pois(viewport_bounds, zoom_level, filters) do
    try do
      clusters = RouteWiseApi.POI.ClusteringServer.get_clusters(
        viewport_bounds,
        zoom_level,
        filters
      )
      {:ok, clusters}
    rescue
      error ->
        require Logger
        Logger.error("Clustering failed for anonymous user: #{inspect(error)}")
        {:error, "Clustering service temporarily unavailable"}
    catch
      :exit, {:timeout, _} ->
        {:error, "Clustering timeout - try zooming in or reducing the area"}
    end
  end

  defp determine_cluster_cache_status(clusters, _operation_type) do
    %{
      status: if(Enum.empty?(clusters), do: "no_data", else: "hit"),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      backend: "ClusteringServer",
      environment: Application.get_env(:phoenix_backend, :env, :dev)
    }
  end

  # Helper functions for nearby POI discovery (legacy)

  defp extract_location(%{"lat" => lat, "lng" => lng}) when is_binary(lat) and is_binary(lng) do
    with {lat_float, ""} <- Float.parse(lat),
         {lng_float, ""} <- Float.parse(lng) do
      {:ok, %{lat: lat_float, lng: lng_float}}
    else
      _ -> {:error, "Invalid lat/lng format"}
    end
  end

  defp extract_location(%{"lat" => lat, "lng" => lng}) when is_number(lat) and is_number(lng) do
    {:ok, %{lat: lat, lng: lng}}
  end

  defp extract_location(_params) do
    {:error, "Missing required parameters: lat, lng"}
  end

  defp get_nearby_pois(location, params) do
    # Use your existing clustering system for nearby POIs!
    radius = params["radius"] || "5000"  # Default 5km
    radius_km = String.to_integer(radius) / 1000.0
    
    # Create viewport bounds from location and radius
    bounds = create_viewport_bounds(location, radius_km)
    
    # Use the POI clustering system to get nearby POIs
    case RouteWiseApi.POI.ClusteringServer.get_clusters(bounds, 15, %{}) do
      clusters when is_list(clusters) ->
        # Extract POIs from clusters and flatten
        pois = clusters
        |> Enum.flat_map(& &1.pois)
        |> Enum.take(50)  # Limit for landing page
        
        {:ok, pois}
      
      _ ->
        {:ok, []}
    end
  rescue
    error ->
      require Logger
      Logger.error("Failed to get nearby POIs: #{inspect(error)}")
      {:ok, []}
  end

  defp create_viewport_bounds(%{lat: lat, lng: lng}, radius_km) do
    # Approximate degrees per km (rough calculation)
    lat_delta = radius_km / 111.0  # ~111km per degree latitude
    lng_delta = radius_km / (111.0 * :math.cos(lat * :math.pi() / 180))  # Adjust for longitude
    
    %{
      north: lat + lat_delta,
      south: lat - lat_delta,
      east: lng + lng_delta,
      west: lng - lng_delta
    }
  end

  # Cache status determination for POI data
  defp determine_poi_cache_status(pois, _operation_type) do
    cond do
      # Empty results
      Enum.empty?(pois) -> 
        :cache_disabled

      # POI data from database - check if it's recent
      is_list(pois) and hd(pois).__struct__ == RouteWiseApi.Trips.POI ->
        poi = hd(pois)
        
        # If POI has recent timestamp, it's likely from cache/database
        case poi.updated_at do
          nil -> {:cache_miss, get_current_backend()}
          timestamp ->
            age_minutes = DateTime.diff(DateTime.utc_now(), timestamp, :minute)
            if age_minutes <= 1440 do  # Less than 24 hours
              {:cache_hit, get_current_backend()}
            else
              {:cache_miss, get_current_backend()}
            end
        end

      # Default case
      true ->
        {:cache_hit, get_current_backend()}
    end
  end

  defp get_current_backend do
    try do
      RouteWiseApi.Caching.backend()
    rescue
      _ -> :database
    end
  end

  # Helper functions for bounds endpoint

  defp extract_bounds_filters(params) do
    try do
      filters = %{}

      # Extract categories
      filters = case params["categories"] do
        nil -> filters
        "" -> filters
        categories_str when is_binary(categories_str) ->
          categories = String.split(categories_str, ",") |> Enum.map(&String.trim/1)
          Map.put(filters, :categories, categories)
        _ -> filters
      end

      # Extract minimum rating
      filters = case params["min_rating"] do
        nil -> filters
        "" -> filters
        rating_str when is_binary(rating_str) ->
          case Float.parse(rating_str) do
            {rating, ""} when rating >= 0.0 and rating <= 5.0 ->
              Map.put(filters, :min_rating, rating)
            _ -> filters
          end
        _ -> filters
      end

      # Extract limit
      filters = case params["limit"] do
        nil -> Map.put(filters, :limit, 100)  # Default limit
        "" -> Map.put(filters, :limit, 100)
        limit_str when is_binary(limit_str) ->
          case Integer.parse(limit_str) do
            {limit, ""} when limit > 0 and limit <= 500 ->
              Map.put(filters, :limit, limit)
            _ -> Map.put(filters, :limit, 100)
          end
        _ -> Map.put(filters, :limit, 100)
      end

      {:ok, filters}
    rescue
      _ -> {:error, :invalid_filters}
    end
  end

  defp get_pois_in_bounds(viewport_bounds, filters) do
    try do
      %{north: north, south: south, east: east, west: west} = viewport_bounds
      limit = Map.get(filters, :limit, 100)

      # Use the existing Places module query function - it returns {:ok, pois}
      case RouteWiseApi.Places.query_pois_in_bounds(south, north, west, east, filters) do
        {:ok, pois} ->
          # Apply limit
          limited_pois = Enum.take(pois, limit)
          {:ok, limited_pois}
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        require Logger
        Logger.error("Failed to get POIs in bounds: #{inspect(error)}")
        {:error, "Database query failed"}
    end
  end

  defp determine_bounds_cache_status(pois, _operation_type) do
    backend = get_current_backend()

    cond do
      # Empty results
      Enum.empty?(pois) ->
        %{
          status: "no_data",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          backend: backend,
          environment: Application.get_env(:phoenix_backend, :env, :dev)
        }

      # POI data from database - check if it's recent
      is_list(pois) and length(pois) > 0 ->
        # Check if this looks like fresh database data
        status = case hd(pois) do
          %{updated_at: nil} -> "miss"
          %{updated_at: timestamp} ->
            age_minutes = DateTime.diff(DateTime.utc_now(), timestamp, :minute)
            if age_minutes <= 1440 do  # Less than 24 hours
              "hit"
            else
              "miss"
            end
          _ -> "hit"
        end

        %{
          status: status,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          backend: backend,
          environment: Application.get_env(:phoenix_backend, :env, :dev)
        }

      # Default case
      true ->
        %{
          status: "hit",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          backend: backend,
          environment: Application.get_env(:phoenix_backend, :env, :dev)
        }
    end
  end
end