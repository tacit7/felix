defmodule RouteWiseApi.POIDeduplicationService do
  @moduledoc """
  Service for deduplicating POIs from multiple data sources.
  
  Handles:
  - Location-based proximity matching (within 100 meters)
  - Name similarity matching using Jaro distance
  - Source priority ordering (database > Google > OSM)
  - Coordinate normalization across different data types
  """
  
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  @earth_radius_meters 6_371_000
  @duplicate_distance_threshold_meters 100
  @name_similarity_threshold 0.8
  @minimum_name_length 3
  
  @doc """
  Combine and deduplicate POIs from multiple sources.
  Database POIs get priority over external sources.
  
  ## Examples
      iex> POIDeduplicationService.combine_and_deduplicate(db_pois, osm_pois)
      [%{name: "Restaurant A", source: "database"}, ...]
  """
  @spec combine_and_deduplicate([map()], [map()]) :: [map()]
  def combine_and_deduplicate(primary_pois, secondary_pois) 
      when is_list(primary_pois) and is_list(secondary_pois) do
    Logger.info("🔗 Starting deduplication process:")
    Logger.info("  📊 Primary POIs: #{length(primary_pois)}")  
    Logger.info("  🗺️  Secondary POIs: #{length(secondary_pois)}")
    
    # Log sample POIs for debugging
    log_sample_pois("Primary", primary_pois, 3)
    log_sample_pois("Secondary", secondary_pois, 3)
    
    # Normalize both sets for comparison
    normalized_primary = Enum.map(primary_pois, &normalize_poi_for_dedup/1)
    normalized_secondary = Enum.map(secondary_pois, &normalize_poi_for_dedup/1)
    
    # Deduplicate based on location and name
    all_pois = normalized_primary ++ normalized_secondary
    deduplicated = deduplicate_by_location_and_name(all_pois)
    
    Logger.info("🎯 Deduplication result: #{length(primary_pois)} + #{length(secondary_pois)} → #{length(deduplicated)} unique POIs")
    
    # Log final source breakdown
    log_final_source_breakdown(deduplicated)
    
    # Sort by priority: database/primary first, then secondary sources
    sort_by_source_priority(deduplicated)
  end
  
  @doc """
  Deduplicate a single list of POIs.
  """
  @spec deduplicate_poi_list([map()]) :: [map()]
  def deduplicate_poi_list(pois) when is_list(pois) do
    Logger.info("🔄 Deduplicating #{length(pois)} POIs from single source")
    
    normalized_pois = Enum.map(pois, &normalize_poi_for_dedup/1)
    deduplicated = deduplicate_by_location_and_name(normalized_pois)
    
    Logger.info("✅ Deduplication complete: #{length(pois)} → #{length(deduplicated)} unique POIs")
    deduplicated
  end
  
  @doc """
  Check if two POIs are duplicates based on name and location.
  """
  @spec are_duplicate_pois?(map(), map()) :: boolean()
  def are_duplicate_pois?(poi1, poi2) when is_map(poi1) and is_map(poi2) do
    normalized_poi1 = normalize_poi_for_dedup(poi1)
    normalized_poi2 = normalize_poi_for_dedup(poi2)
    
    is_duplicate?(normalized_poi1, [normalized_poi2])
  end
  
  # Private implementation functions
  
  defp normalize_poi_for_dedup(poi) when is_map(poi) do
    # Handle coordinates from different sources safely
    lat = extract_latitude(poi)
    lng = extract_longitude(poi)
    
    assert!(is_float(lat) or is_nil(lat), "Invalid latitude after normalization: #{inspect(lat)}")
    assert!(is_float(lng) or is_nil(lng), "Invalid longitude after normalization: #{inspect(lng)}")
    
    name = extract_normalized_name(poi)
    
    Map.merge(poi, %{
      normalized_name: name,
      lat_float: lat,
      lng_float: lng
    })
  end
  
  defp extract_latitude(poi) do
    lat_value = Map.get(poi, :lat) || Map.get(poi, :latitude)
    normalize_coordinate(lat_value)
  end
  
  defp extract_longitude(poi) do
    lng_value = Map.get(poi, :lng) || Map.get(poi, :longitude) || Map.get(poi, :lon)
    normalize_coordinate(lng_value)
  end
  
  defp normalize_coordinate(nil), do: 0.0
  defp normalize_coordinate(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp normalize_coordinate(value) when is_number(value), do: value * 1.0
  defp normalize_coordinate(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  defp normalize_coordinate(_), do: 0.0
  
  defp extract_normalized_name(poi) do
    raw_name = Map.get(poi, :name, "")
    
    assert!(is_binary(raw_name), "POI name must be a string, got: #{inspect(raw_name)}")
    
    raw_name
    |> String.downcase()
    |> String.trim()
  end
  
  defp deduplicate_by_location_and_name(pois) when is_list(pois) do
    pois
    |> Enum.reduce([], fn poi, acc ->
      if is_duplicate?(poi, acc) do
        acc  # Skip duplicate
      else
        [poi | acc]  # Add unique POI
      end
    end)
    |> Enum.reverse()
  end
  
  defp is_duplicate?(poi, existing_pois) when is_map(poi) and is_list(existing_pois) do
    poi_name = Map.get(poi, :normalized_name, "")
    poi_lat = Map.get(poi, :lat_float, 0.0)
    poi_lng = Map.get(poi, :lng_float, 0.0)
    
    Enum.any?(existing_pois, fn existing ->
      existing_name = Map.get(existing, :normalized_name, "")
      existing_lat = Map.get(existing, :lat_float, 0.0)
      existing_lng = Map.get(existing, :lng_float, 0.0)
      
      # Check name similarity
      name_similar = names_are_similar?(poi_name, existing_name)
      
      # Check location proximity
      distance_meters = haversine_distance(poi_lat, poi_lng, existing_lat, existing_lng)
      location_close = distance_meters < @duplicate_distance_threshold_meters
      
      name_similar and location_close
    end)
  end
  
  defp names_are_similar?(name1, name2) when is_binary(name1) and is_binary(name2) do
    cond do
      # Exact match
      name1 == name2 -> true
      
      # Skip very short names
      String.length(name1) < @minimum_name_length or String.length(name2) < @minimum_name_length -> false
      
      # Jaro distance similarity
      true -> String.jaro_distance(name1, name2) > @name_similarity_threshold
    end
  end
  defp names_are_similar?(_, _), do: false
  
  defp haversine_distance(lat1, lng1, lat2, lng2) 
       when is_float(lat1) and is_float(lng1) and is_float(lat2) and is_float(lng2) do
    # Convert to radians
    lat1_rad = lat1 * :math.pi() / 180
    lat2_rad = lat2 * :math.pi() / 180
    delta_lat = (lat2 - lat1) * :math.pi() / 180
    delta_lng = (lng2 - lng1) * :math.pi() / 180
    
    # Haversine formula
    a = :math.sin(delta_lat / 2) * :math.sin(delta_lat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(delta_lng / 2) * :math.sin(delta_lng / 2)
    
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    
    @earth_radius_meters * c
  end
  defp haversine_distance(_, _, _, _), do: 999_999.0  # Invalid coordinates = very large distance
  
  defp sort_by_source_priority(pois) when is_list(pois) do
    Enum.sort_by(pois, fn poi ->
      case Map.get(poi, :source) do
        # Database sources get highest priority (0)
        source when source in ["database", "manual", "google_places"] -> 0
        
        # External APIs get medium priority (1)
        "location_iq" -> 1
        
        # Community data gets lowest priority (2)
        "openstreetmap" -> 2
        
        # Unknown sources get lowest priority
        _ -> 3
      end
    end)
  end
  
  defp log_sample_pois(label, pois, count) when is_list(pois) do
    Enum.take(pois, count)
    |> Enum.each(fn poi ->
      name = Map.get(poi, :name, "Unnamed")
      id = Map.get(poi, :id, "no-id")
      source = Map.get(poi, :source, "unknown")
      Logger.info("  #{label}: #{name} (#{id}, source: #{source})")
    end)
  end
  
  defp log_final_source_breakdown(deduplicated_pois) when is_list(deduplicated_pois) do
    source_counts = deduplicated_pois
    |> Enum.group_by(&Map.get(&1, :source, "unknown"))
    |> Enum.map(fn {source, pois} -> {source, length(pois)} end)
    |> Enum.sort_by(fn {_source, count} -> -count end)  # Sort by count descending
    
    Enum.each(source_counts, fn {source, count} ->
      Logger.info("  Final #{source}: #{count} POIs")
    end)
  end
end