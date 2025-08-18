defmodule RouteWiseApi.POI.SpatialCluster do
  @moduledoc """
  Spatial clustering algorithms for POI data.
  
  Implements grid-based clustering optimized for map viewport rendering.
  """
  
  require Logger
  
  @doc """
  Grid-based clustering algorithm optimized for map rendering performance.
  
  Groups POIs into spatial grid cells and creates cluster markers for cells
  containing multiple POIs. Individual POIs are preserved for sparse areas.
  
  ## Parameters
  - pois: List of POI structs with lat/lng coordinates
  - config: %{grid_size: float, min_cluster_size: integer}
  
  ## Returns
  List of cluster objects ready for map rendering
  """
  def grid_cluster(pois, config) do
    grid_size = config.grid_size
    min_cluster_size = config.min_cluster_size
    
    # Step 1: Group POIs into grid cells
    grid_cells = group_into_grid_cells(pois, grid_size)
    
    # Step 2: Convert grid cells to clusters or individual markers
    grid_cells
    |> Enum.flat_map(fn {_cell_key, cell_pois} ->
      if length(cell_pois) >= min_cluster_size do
        # Create cluster for this grid cell
        [create_cluster_marker(cell_pois)]
      else
        # Keep as individual POI markers
        Enum.map(cell_pois, &create_individual_marker/1)
      end
    end)
    |> Enum.sort_by(& &1.count, :desc)  # Sort by cluster size for consistent rendering
  end
  
  @doc """
  DBSCAN clustering for more sophisticated grouping.
  
  Groups POIs based on density rather than grid cells. Better for
  irregular POI distributions but more computationally expensive.
  """
  def dbscan_cluster(pois, eps_degrees, min_points) do
    # Convert POIs to points with indices
    points = pois
    |> Enum.with_index()
    |> Enum.map(fn {poi, idx} -> 
      %{
        id: idx,
        lat: poi.latitude || poi.lat,
        lng: poi.longitude || poi.lng,
        poi: poi,
        cluster_id: nil,
        visited: false
      }
    end)
    
    # Run DBSCAN algorithm
    {clustered_points, _cluster_count} = dbscan_algorithm(points, eps_degrees, min_points)
    
    # Convert clustered points to cluster markers
    clustered_points
    |> Enum.group_by(& &1.cluster_id)
    |> Enum.flat_map(fn {cluster_id, cluster_points} ->
      case cluster_id do
        nil ->
          # Noise points become individual markers
          Enum.map(cluster_points, fn point -> create_individual_marker(point.poi) end)
        
        _cluster_id ->
          # Clustered points become cluster markers
          cluster_pois = Enum.map(cluster_points, & &1.poi)
          [create_cluster_marker(cluster_pois)]
      end
    end)
  end
  
  # Private helper functions
  
  defp group_into_grid_cells(pois, grid_size) do
    pois
    |> Enum.group_by(&calculate_grid_cell(&1, grid_size))
    |> Enum.filter(fn {_cell_key, cell_pois} -> length(cell_pois) > 0 end)
  end
  
  defp calculate_grid_cell(poi, grid_size) do
    lat = poi.latitude || poi.lat
    lng = poi.longitude || poi.lng
    
    # Calculate grid cell coordinates
    grid_lat = Float.floor(lat / grid_size) * grid_size
    grid_lng = Float.floor(lng / grid_size) * grid_size
    
    # Return cell key as tuple for efficient grouping
    {grid_lat, grid_lng}
  end
  
  defp create_cluster_marker(pois) when is_list(pois) and length(pois) > 0 do
    # Calculate cluster center (centroid)
    {total_lat, total_lng} = pois
    |> Enum.reduce({0.0, 0.0}, fn poi, {lat_sum, lng_sum} ->
      lat = poi.latitude || poi.lat
      lng = poi.longitude || poi.lng
      {lat_sum + lat, lng_sum + lng}
    end)
    
    count = length(pois)
    center_lat = total_lat / count
    center_lng = total_lng / count
    
    # Calculate category breakdown
    category_breakdown = pois
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, category_pois} -> {category, length(category_pois)} end)
    |> Enum.into(%{})
    
    # Calculate average rating
    ratings = pois
    |> Enum.map(& &1.rating)
    |> Enum.filter(&is_number/1)
    
    avg_rating = if length(ratings) > 0 do
      Enum.sum(ratings) / length(ratings)
    else
      0.0
    end
    
    # Generate unique cluster ID
    cluster_id = generate_cluster_id(center_lat, center_lng, count)
    
    %{
      id: cluster_id,
      type: "cluster",
      lat: center_lat,
      lng: center_lng,
      count: count,
      pois: pois,
      category_breakdown: category_breakdown,
      avg_rating: Float.round(avg_rating, 1),
      cached_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
  
  defp create_individual_marker(poi) do
    %{
      id: "poi_#{poi.id}",
      type: "single_poi",
      lat: poi.latitude || poi.lat,
      lng: poi.longitude || poi.lng,
      count: 1,
      pois: [poi],
      category_breakdown: %{poi.category => 1},
      avg_rating: poi.rating || 0.0,
      cached_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
  
  defp generate_cluster_id(lat, lng, count) do
    # Create deterministic cluster ID for caching consistency
    lat_str = lat |> Float.round(6) |> Float.to_string()
    lng_str = lng |> Float.round(6) |> Float.to_string()
    
    "cluster_#{lat_str}_#{lng_str}_#{count}"
  end
  
  # DBSCAN algorithm implementation
  
  defp dbscan_algorithm(points, eps, min_points) do
    cluster_id = 1
    
    {final_points, final_cluster_id} = Enum.reduce(points, {points, cluster_id}, fn point, {current_points, current_cluster_id} ->
      point_idx = point.id
      current_point = Enum.at(current_points, point_idx)
      
      if current_point.visited do
        {current_points, current_cluster_id}
      else
        # Mark as visited
        updated_points = List.update_at(current_points, point_idx, fn p -> %{p | visited: true} end)
        
        # Find neighbors
        neighbors = find_neighbors(current_point, updated_points, eps)
        
        if length(neighbors) < min_points do
          # Mark as noise
          {updated_points, current_cluster_id}
        else
          # Create new cluster
          {clustered_points, next_cluster_id} = expand_cluster(
            updated_points, 
            current_point, 
            neighbors, 
            current_cluster_id, 
            eps, 
            min_points
          )
          {clustered_points, next_cluster_id}
        end
      end
    end)
    
    {final_points, final_cluster_id - 1}
  end
  
  defp find_neighbors(point, all_points, eps) do
    all_points
    |> Enum.filter(fn other_point ->
      point.id != other_point.id and 
      haversine_distance(point.lat, point.lng, other_point.lat, other_point.lng) <= eps
    end)
  end
  
  defp expand_cluster(points, point, neighbors, cluster_id, eps, min_points) do
    # Assign cluster ID to point
    point_idx = point.id
    updated_points = List.update_at(points, point_idx, fn p -> %{p | cluster_id: cluster_id} end)
    
    # Process neighbors
    {final_points, _} = Enum.reduce(neighbors, {updated_points, neighbors}, fn neighbor, {current_points, current_neighbors} ->
      neighbor_idx = neighbor.id
      current_neighbor = Enum.at(current_points, neighbor_idx)
      
      updated_points_step1 = if not current_neighbor.visited do
        # Mark neighbor as visited
        step1_points = List.update_at(current_points, neighbor_idx, fn p -> %{p | visited: true} end)
        
        # Find neighbor's neighbors
        neighbor_neighbors = find_neighbors(current_neighbor, step1_points, eps)
        
        if length(neighbor_neighbors) >= min_points do
          # Add to neighbors list
          step1_points
        else
          step1_points
        end
      else
        current_points
      end
      
      # If neighbor is not in any cluster, add to current cluster
      final_points_step = if Enum.at(updated_points_step1, neighbor_idx).cluster_id == nil do
        List.update_at(updated_points_step1, neighbor_idx, fn p -> %{p | cluster_id: cluster_id} end)
      else
        updated_points_step1
      end
      
      {final_points_step, current_neighbors}
    end)
    
    {final_points, cluster_id + 1}
  end
  
  # Calculate haversine distance between two points in degrees
  defp haversine_distance(lat1, lng1, lat2, lng2) do
    # Convert to radians
    lat1_rad = lat1 * :math.pi() / 180
    lng1_rad = lng1 * :math.pi() / 180
    lat2_rad = lat2 * :math.pi() / 180
    lng2_rad = lng2 * :math.pi() / 180
    
    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlng = lng2_rad - lng1_rad
    
    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(dlng / 2) * :math.sin(dlng / 2)
    
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    
    # Earth radius in km
    earth_radius = 6371.0
    
    # Convert back to approximate degrees (for grid clustering)
    distance_km = earth_radius * c
    distance_km / 111.0  # Approximate degrees (1 degree ≈ 111km)
  end
end