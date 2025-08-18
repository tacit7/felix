defmodule RouteWiseApi.POIProximityUtils do
  @moduledoc """
  Utilities for calculating distances and ordering POIs by proximity.
  
  Provides efficient distance calculations and sorting for optimal user experience.
  """
  
  @doc """
  Calculates the haversine distance between two points in kilometers.
  
  ## Parameters
  - lat1, lng1: First point coordinates
  - lat2, lng2: Second point coordinates
  
  ## Returns
  Distance in kilometers (float)
  
  ## Examples
      iex> RouteWiseApi.POIProximityUtils.haversine_distance(37.7749, -122.4194, 37.7849, -122.4094)
      1.2345
  """
  def haversine_distance(lat1, lng1, lat2, lng2) do
    # Convert degrees to radians
    lat1_rad = degrees_to_radians(lat1)
    lng1_rad = degrees_to_radians(lng1)
    lat2_rad = degrees_to_radians(lat2)
    lng2_rad = degrees_to_radians(lng2)
    
    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlng = lng2_rad - lng1_rad
    
    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(dlng / 2) * :math.sin(dlng / 2)
        
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    
    # Earth's radius in kilometers
    6371 * c
  end
  
  @doc """
  Sorts POIs by distance from a reference point.
  
  ## Parameters
  - pois: List of POI structs with latitude/longitude fields
  - reference_lat: Reference point latitude
  - reference_lng: Reference point longitude
  - options: Sorting options
    - :limit - Maximum number of POIs to return
    - :max_distance_km - Maximum distance in km (filters out POIs beyond this)
    - :add_distance - Whether to add distance field to each POI
  
  ## Returns
  List of POIs sorted by proximity (closest first)
  
  ## Examples
      pois = [
        %{name: "Restaurant", latitude: 37.7749, longitude: -122.4194},
        %{name: "Attraction", latitude: 37.7849, longitude: -122.4094}
      ]
      
      RouteWiseApi.POIProximityUtils.sort_pois_by_proximity(
        pois, 37.7799, -122.4144, 
        limit: 10, add_distance: true
      )
  """
  def sort_pois_by_proximity(pois, reference_lat, reference_lng, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    max_distance_km = Keyword.get(opts, :max_distance_km)
    add_distance = Keyword.get(opts, :add_distance, false)
    
    pois
    |> Enum.map(fn poi ->
      distance = calculate_poi_distance(poi, reference_lat, reference_lng)
      
      if add_distance do
        Map.put(poi, :distance_km, Float.round(distance, 2))
      else
        {poi, distance}
      end
    end)
    |> filter_by_max_distance(max_distance_km, add_distance)
    |> sort_by_distance(add_distance)
    |> apply_limit(limit, add_distance)
  end
  
  @doc """
  Sorts POIs by their proximity to a route path.
  
  For route-based ordering, finds the closest point on the route to each POI
  and orders them by route progression order.
  
  ## Parameters
  - pois: List of POI structs
  - route_points: List of route coordinate points [{lat, lng}, ...]
  - options: Sorting options
  
  ## Returns
  List of POIs sorted by route progression order
  """
  def sort_pois_by_route_proximity(pois, route_points, opts \\ []) when is_list(route_points) do
    if Enum.empty?(route_points) do
      pois
    else
      pois
      |> Enum.map(fn poi ->
        {closest_route_index, min_distance} = find_closest_route_point(poi, route_points)
        {poi, closest_route_index, min_distance}
      end)
      |> Enum.sort_by(fn {_poi, route_index, _distance} -> route_index end)
      |> Enum.map(fn {poi, _route_index, distance} ->
        if Keyword.get(opts, :add_distance, false) do
          Map.put(poi, :distance_to_route_km, Float.round(distance, 2))
        else
          poi
        end
      end)
      |> apply_limit(Keyword.get(opts, :limit), true)
    end
  end
  
  @doc """
  Calculates the center point (centroid) of a list of POIs.
  
  Useful for determining cluster centers or route midpoints.
  """
  def calculate_centroid(pois) when is_list(pois) and length(pois) > 0 do
    {total_lat, total_lng, count} = 
      Enum.reduce(pois, {0, 0, 0}, fn poi, {lat_sum, lng_sum, count} ->
        poi_lat = get_poi_latitude(poi)
        poi_lng = get_poi_longitude(poi)
        {lat_sum + poi_lat, lng_sum + poi_lng, count + 1}
      end)
    
    %{
      latitude: total_lat / count,
      longitude: total_lng / count
    }
  end
  def calculate_centroid(_), do: %{latitude: 0, longitude: 0}
  
  # Private helper functions
  
  defp degrees_to_radians(degrees), do: degrees * :math.pi() / 180
  
  defp calculate_poi_distance(poi, ref_lat, ref_lng) do
    poi_lat = get_poi_latitude(poi)
    poi_lng = get_poi_longitude(poi)
    haversine_distance(poi_lat, poi_lng, ref_lat, ref_lng)
  end
  
  defp get_poi_latitude(poi) do
    cond do
      Map.has_key?(poi, :latitude) -> poi.latitude |> to_float()
      Map.has_key?(poi, "latitude") -> poi["latitude"] |> to_float()
      Map.has_key?(poi, :lat) -> poi.lat |> to_float() 
      Map.has_key?(poi, "lat") -> poi["lat"] |> to_float()
      true -> 0.0
    end
  end
  
  defp get_poi_longitude(poi) do
    cond do
      Map.has_key?(poi, :longitude) -> poi.longitude |> to_float()
      Map.has_key?(poi, "longitude") -> poi["longitude"] |> to_float()
      Map.has_key?(poi, :lng) -> poi.lng |> to_float()
      Map.has_key?(poi, "lng") -> poi["lng"] |> to_float()
      true -> 0.0
    end
  end
  
  defp to_float(value) when is_number(value), do: value / 1
  defp to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, ""} -> float_val
      _ -> 0.0
    end
  end
  defp to_float(_), do: 0.0
  
  defp filter_by_max_distance(poi_distance_pairs, nil, _add_distance), do: poi_distance_pairs
  defp filter_by_max_distance(poi_distance_pairs, max_distance_km, add_distance) do
    Enum.filter(poi_distance_pairs, fn item ->
      distance = if add_distance, do: item.distance_km, else: elem(item, 1)
      distance <= max_distance_km
    end)
  end
  
  defp sort_by_distance(poi_distance_pairs, add_distance) do
    Enum.sort_by(poi_distance_pairs, fn item ->
      if add_distance, do: item.distance_km, else: elem(item, 1)
    end)
  end
  
  defp apply_limit(poi_list, nil, _add_distance), do: poi_list
  defp apply_limit(poi_list, limit, add_distance) when is_integer(limit) do
    result = Enum.take(poi_list, limit)
    
    if add_distance do
      result
    else
      Enum.map(result, &elem(&1, 0))
    end
  end
  
  defp find_closest_route_point(poi, route_points) do
    poi_lat = get_poi_latitude(poi)
    poi_lng = get_poi_longitude(poi)
    
    route_points
    |> Enum.with_index()
    |> Enum.map(fn {{lat, lng}, index} ->
      distance = haversine_distance(poi_lat, poi_lng, lat, lng)
      {index, distance}
    end)
    |> Enum.min_by(fn {_index, distance} -> distance end)
  end
end