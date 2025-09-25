defmodule RouteWiseApi.POIFormatterService do
  @moduledoc """
  Service for formatting and converting POI data between different formats.
  
  Handles:
  - Google Places to internal POI format conversion
  - OSM to internal POI format conversion
  - Database POI formatting for API responses
  - Image and photo processing
  - Rating and coordinate normalization
  """
  
  alias RouteWiseApi.ImageService
  alias RouteWiseApi.TypeUtils
  
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert
  
  @doc """
  Convert Google Places API result to internal POI format.
  """
  @spec convert_google_to_poi_format(map()) :: map()
  def convert_google_to_poi_format(google_place) when is_map(google_place) do
    assert!(Map.has_key?(google_place, "place_id"), "Google place must have place_id")
    assert!(Map.has_key?(google_place, "name"), "Google place must have name")
    
    %{
      id: "google_#{google_place["place_id"]}",
      name: google_place["name"],
      categories: google_place["types"] || [],
      lat: TypeUtils.ensure_float(google_place["geometry"]["location"]["lat"]),
      lng: TypeUtils.ensure_float(google_place["geometry"]["location"]["lng"]),
      rating: google_place["rating"],
      address: google_place["formatted_address"] || google_place["vicinity"],
      phone: google_place["formatted_phone_number"],
      website: google_place["website"],
      price_level: google_place["price_level"],
      opening_hours: format_google_opening_hours(google_place["opening_hours"]),
      source: "google_places",
      google_place_id: google_place["place_id"],
      photos: extract_google_photos(google_place["photos"]),
      reviews_count: google_place["user_ratings_total"] || 0,
      google_data: google_place  # Store full API response
    }
  end
  
  @doc """
  Convert OSM place to internal POI format.
  """
  @spec convert_osm_to_poi_format(map()) :: map()
  def convert_osm_to_poi_format(osm_place) when is_map(osm_place) do
    assert!(Map.has_key?(osm_place, :osm_id), "OSM place must have osm_id")
    assert!(Map.has_key?(osm_place, :name), "OSM place must have name")
    
    place_types = Map.get(osm_place, :place_types, [])
    category = Map.get(osm_place, :category, "other")
    
    %{
      id: "osm_#{Map.get(osm_place, :osm_id)}_#{Map.get(osm_place, :osm_type)}",
      placeId: "osm_#{Map.get(osm_place, :osm_id)}_#{Map.get(osm_place, :osm_type)}",
      name: Map.get(osm_place, :name),
      placeTypes: place_types,
      lat: TypeUtils.ensure_float(Map.get(osm_place, :lat)),
      lng: TypeUtils.ensure_float(Map.get(osm_place, :lng)),
      rating: to_string(Map.get(osm_place, :rating, 4.0)),
      reviewCount: nil,
      address: Map.get(osm_place, :address),
      phoneNumber: Map.get(osm_place, :phone),
      website: Map.get(osm_place, :website),
      openingHours: Map.get(osm_place, :opening_hours),
      distance: TypeUtils.ensure_float(Map.get(osm_place, :distance)),
      
      # OSM source identification
      source: "openstreetmap",
      dataProvider: "OpenStreetMap",
      osmId: Map.get(osm_place, :osm_id),
      osmType: Map.get(osm_place, :osm_type),
      osmUrl: "https://www.openstreetmap.org/#{Map.get(osm_place, :osm_type)}/#{Map.get(osm_place, :osm_id)}",
      
      # OSM-specific metadata
      isCommunityData: true,
      dataSource: %{
        name: "OpenStreetMap",
        type: "community", 
        url: "https://www.openstreetmap.org",
        license: "ODbL",
        attribution: "© OpenStreetMap contributors"
      },
      
      # Enhanced descriptions
      description: generate_osm_description(osm_place, category),
      
      # Default compatibility fields
      priceLevel: nil,
      photos: [],
      cachedAt: DateTime.utc_now() |> DateTime.to_iso8601(),
      lastUpdated: DateTime.utc_now() |> DateTime.to_iso8601(),
      createdAt: DateTime.utc_now() |> DateTime.to_iso8601(),
      updatedAt: DateTime.utc_now() |> DateTime.to_iso8601(),
      isOpen: parse_osm_opening_hours(Map.get(osm_place, :opening_hours)),
      googleData: %{},
      locationIqData: %{},
      
      # Image system integration
      imageUrl: get_osm_category_image(category),
      images: generate_poi_images("osm_#{Map.get(osm_place, :osm_id)}_#{Map.get(osm_place, :osm_type)}"),
      categoryIcon: generate_category_icon_url(get_fallback_category(place_types))
    }
  end
  
  @doc """
  Format database POI for API response.
  """
  @spec format_poi_for_response(map()) :: map()
  def format_poi_for_response(%{} = poi) do
    # Extract categories from both possible fields - handle Ecto struct vs map
    raw_categories = cond do
      # For Ecto struct (from database)
      Map.has_key?(poi, :__struct__) and is_list(Map.get(poi, :categories)) ->
        Map.get(poi, :categories, [])
      # For API data with place_types
      is_list(Map.get(poi, :place_types)) ->
        Map.get(poi, :place_types, [])
      # For map data with categories
      is_list(Map.get(poi, :categories)) ->
        Map.get(poi, :categories, [])
      # Fallback
      true ->
        []
    end

    Logger.info("🐛 EXTRACTED CATEGORIES for #{Map.get(poi, :name)}: #{inspect(raw_categories)}")
    %{
      # Core identification
      id: Map.get(poi, :id),
      placeId: Map.get(poi, :place_id) || Map.get(poi, :google_place_id) || "place_#{Map.get(poi, :id)}",
      googlePlaceId: Map.get(poi, :google_place_id),
      locationIqPlaceId: Map.get(poi, :location_iq_place_id),
      
      # Basic information
      name: Map.get(poi, :name, "Unknown Place"),
      address: Map.get(poi, :formatted_address, "Address not available"),
      description: Map.get(poi, :description) || generate_poi_description(poi),
      
      # Geographic data  
      lat: format_coordinate(Map.get(poi, :latitude) || Map.get(poi, :lat)),
      lng: format_coordinate(Map.get(poi, :longitude) || Map.get(poi, :lng) || Map.get(poi, :lon)),
      
      # Business information
      rating: format_rating(Map.get(poi, :rating)),
      reviewCount: Map.get(poi, :reviews_count, 0),
      priceLevel: Map.get(poi, :price_level),
      popularityScore: Map.get(poi, :popularity_score, 0),
      phoneNumber: Map.get(poi, :phone_number),
      website: Map.get(poi, :website),
      
      # Categories - preserve raw place types (check both field names for compatibility)
      placeTypes: raw_categories,
      categories: format_categories_to_readable(raw_categories),  # Frontend expects readable categories
      
      # Operational data
      openingHours: Map.get(poi, :opening_hours),
      isOpen: get_opening_status(poi),
      photos: get_photo_array(poi),
      
      # Images and media
      imageUrl: get_place_image(poi),
      images: generate_poi_images(Map.get(poi, :id)),
      categoryIcon: generate_category_icon_url(get_fallback_category(raw_categories)),
      wikiImage: Map.get(poi, :wiki_image),
      
      # External integrations
      tripadvisorUrl: Map.get(poi, :tripadvisor_url),
      googleData: get_simplified_google_data(poi),
      locationIqData: get_simplified_location_iq_data(poi),
      
      # Tips and insights
      tips: Map.get(poi, :tips, []),
      
      # Classification
      hiddenGem: Map.get(poi, :hidden_gem, false),
      hiddenGemReason: Map.get(poi, :hidden_gem_reason),
      overrated: Map.get(poi, :overrated, false),
      overratedReason: Map.get(poi, :overrated_reason),
      curated: true,
      
      # TripAdvisor data
      tripadvisorRating: format_rating(Map.get(poi, :tripadvisor_rating)),
      tripadvisorReviewCount: Map.get(poi, :tripadvisor_review_count),
      
      # Visit information
      entryFee: Map.get(poi, :entry_fee),
      bestTimeToVisit: Map.get(poi, :best_time_to_visit),
      accessibility: Map.get(poi, :accessibility),
      durationSuggested: Map.get(poi, :duration_suggested),
      
      # Metadata
      relatedPlaces: Map.get(poi, :related_places, []),
      localName: Map.get(poi, :local_name),
      wikidataId: Map.get(poi, :wikidata_id),
      
      # Timestamps
      createdAt: format_timestamp(Map.get(poi, :inserted_at)),
      updatedAt: format_timestamp(Map.get(poi, :updated_at)),
      cachedAt: format_timestamp(Map.get(poi, :cached_at)),
      lastUpdated: format_timestamp(Map.get(poi, :last_updated)),
      
      # Computed fields
      distance: Map.get(poi, :distance),
      source: determine_data_source(poi)
    }
  end
  
  @doc """
  Format list of POIs, filtering out invalid coordinates.
  """
  @spec format_pois_list([map()]) :: [map()]
  def format_pois_list(pois) when is_list(pois) do
    pois
    |> Enum.map(&format_poi_for_response/1)
    |> Enum.filter(&has_valid_coordinates?/1)
  end
  def format_pois_list(_), do: []
  
  # Private helper functions
  
  defp format_google_opening_hours(nil), do: nil
  defp format_google_opening_hours(%{"open_now" => open_now}), do: %{open_now: open_now}
  defp format_google_opening_hours(opening_hours), do: opening_hours
  
  defp extract_google_photos(nil), do: []
  defp extract_google_photos([]), do: []
  defp extract_google_photos(photos) when is_list(photos) do
    Enum.take(photos, 3) |> Enum.map(fn photo ->
      %{
        photo_reference: photo["photo_reference"],
        width: photo["width"],
        height: photo["height"]
      }
    end)
  end
  
  defp generate_osm_description(osm_place, category) do
    name = Map.get(osm_place, :name, "Place")
    cuisine = Map.get(osm_place, :cuisine)
    brand = Map.get(osm_place, :brand)
    
    base_description = cond do
      brand && cuisine ->
        "#{get_readable_osm_category(category)} • #{brand} • #{cuisine} cuisine"
      brand ->
        "#{get_readable_osm_category(category)} • #{brand}"
      cuisine ->
        "#{get_readable_osm_category(category)} • #{cuisine} cuisine"  
      true ->
        get_readable_osm_category(category)
    end
    
    "#{base_description} • Community data"
  end
  
  defp get_readable_osm_category(category) do
    case category do
      "restaurant" -> "Restaurant"
      "cafe" -> "Cafe"
      "hotel" -> "Hotel"
      "attraction" -> "Tourist Attraction"
      "shop" -> "Store"
      "bank" -> "Bank"
      "hospital" -> "Hospital"
      "school" -> "School"
      "church" -> "Place of Worship"
      "park" -> "Park"
      "museum" -> "Museum"
      "gas_station" -> "Gas Station"
      "pharmacy" -> "Pharmacy"
      "grocery" -> "Grocery Store"
      "clothing" -> "Clothing Store"
      "electronics" -> "Electronics Store"
      "fuel" -> "Gas Station"
      "accommodation" -> "Accommodation"
      _ -> String.replace(category, "_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
    end
  end
  
  defp parse_osm_opening_hours(nil), do: nil
  defp parse_osm_opening_hours(""), do: nil
  defp parse_osm_opening_hours("24/7"), do: true
  defp parse_osm_opening_hours(hours_string) when is_binary(hours_string) do
    current_hour = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string() |> String.slice(0, 2) |> String.to_integer()
    
    cond do
      String.contains?(hours_string, "24/7") -> true
      String.contains?(hours_string, "closed") -> false
      current_hour >= 8 and current_hour <= 22 -> true  # Business hours assumption
      true -> false
    end
  rescue
    _ -> nil
  end
  defp parse_osm_opening_hours(_), do: nil
  
  defp get_osm_category_image(category) do
    case category do
      "restaurant" -> "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop"
      "cafe" -> "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400&h=300&fit=crop"
      "hotel" -> "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=300&fit=crop"
      "attraction" -> "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop"
      "shop" -> "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop"
      "bank" -> "https://images.unsplash.com/photo-1541354329998-f4d9a9f9297f?w=400&h=300&fit=crop"
      "hospital" -> "https://images.unsplash.com/photo-1587351021759-3e566b6af7cc?w=400&h=300&fit=crop"
      "school" -> "https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=400&h=300&fit=crop"
      "church" -> "https://images.unsplash.com/photo-1520637836862-4d197d17c2a4?w=400&h=300&fit=crop"
      "park" -> "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop"
      "museum" -> "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=300&fit=crop"
      "gas_station" -> "https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=400&h=300&fit=crop"
      "pharmacy" -> "https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=400&h=300&fit=crop"
      "grocery" -> "https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400&h=300&fit=crop"
      _ -> "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop"
    end
  end
  
  defp generate_poi_description(poi) do
    # Convert database POI to Google Places-like format for description generation
    google_data = %{
      "editorial_summary" => Map.get(poi, :google_data, %{}) |> get_in(["editorial_summary"]),
      "business_status" => Map.get(poi, :google_data, %{}) |> get_in(["business_status"]),
      "types" => Map.get(poi, :place_types, []),
      "rating" => TypeUtils.ensure_float(Map.get(poi, :rating)),
      "user_ratings_total" => Map.get(poi, :reviews_count)
    }
    
    get_enhanced_description(google_data)
  end
  
  defp get_enhanced_description(place_data) do
    cond do
      # Try editorial summary first
      get_in(place_data, ["editorial_summary", "overview"]) ->
        get_in(place_data, ["editorial_summary", "overview"])
      
      # Build from business data
      place_data["business_status"] == "OPERATIONAL" and place_data["types"] ->
        types = place_data["types"] || []
        primary_type = get_readable_type(types)
        rating = place_data["rating"]
        review_count = place_data["user_ratings_total"]
        
        case {rating, review_count} do
          {nil, _} -> "#{primary_type}"
          {rating, nil} -> "#{primary_type} • #{rating}★"
          {rating, count} when count > 0 -> "#{primary_type} • #{rating}★ (#{count} reviews)"
          _ -> "#{primary_type}"
        end
      
      # Fallback to readable type
      place_data["types"] ->
        get_readable_type(place_data["types"])
      
      # Last resort
      true ->
        "Point of interest"
    end
  end
  
  defp get_readable_type(types) when is_list(types) do
    readable_mapping = %{
      "restaurant" => "Restaurant",
      "food" => "Restaurant", 
      "meal_takeaway" => "Takeout Restaurant",
      "cafe" => "Cafe",
      "tourist_attraction" => "Tourist Attraction",
      "park" => "Park",
      "amusement_park" => "Amusement Park",
      "museum" => "Museum",
      "art_gallery" => "Art Gallery",
      "shopping_mall" => "Shopping Mall",
      "store" => "Store",
      "gas_station" => "Gas Station",
      "lodging" => "Hotel",
      "church" => "Church",
      "hospital" => "Hospital",
      "school" => "School",
      "bank" => "Bank",
      "pharmacy" => "Pharmacy",
      "gym" => "Gym",
      "beauty_salon" => "Beauty Salon",
      "night_club" => "Night Club",
      "bar" => "Bar",
      "movie_theater" => "Movie Theater"
    }
    
    # Find first type with readable mapping
    readable_type = Enum.find_value(types, fn type ->
      readable_mapping[type]
    end)
    
    # Fallback to formatted first type
    readable_type ||
      case List.first(types) do
        nil -> "Point of Interest"
        first_type when is_binary(first_type) ->
          first_type
          |> String.replace("_", " ")
          |> String.split(" ")
          |> Enum.map(&String.capitalize/1)
          |> Enum.join(" ")
        _ -> "Point of Interest"
      end
  end
  defp get_readable_type(_), do: "Point of Interest"
  
  # Utility functions for formatting
  
  defp format_rating(nil), do: "4.0"
  defp format_rating(%Decimal{} = rating), do: Decimal.to_string(rating)
  defp format_rating(rating) when is_number(rating), do: Float.to_string(rating)
  defp format_rating(rating) when is_binary(rating), do: rating
  defp format_rating(_), do: "4.0"
  
  defp format_coordinate(nil), do: nil
  defp format_coordinate(%Decimal{} = coord) do
    float_val = Decimal.to_float(coord)
    if float_val == 0.0, do: nil, else: float_val
  end
  defp format_coordinate(coord) when is_number(coord) do
    if coord == 0.0, do: nil, else: coord
  end
  defp format_coordinate(_), do: nil
  
  defp format_timestamp(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp format_timestamp(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_timestamp(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC") |> DateTime.to_iso8601()
  defp format_timestamp(_), do: DateTime.utc_now() |> DateTime.to_iso8601()
  
  defp has_valid_coordinates?(%{lat: lat, lng: lng}) do
    not is_nil(lat) and not is_nil(lng) and lat != 0.0 and lng != 0.0
  end
  defp has_valid_coordinates?(_), do: false
  
  defp format_categories_to_readable([]), do: []
  defp format_categories_to_readable(place_types) when is_list(place_types) do
    place_types
    |> Enum.map(fn type ->
      # Use the existing get_readable_type function but handle individual types
      case get_readable_type([type]) do
        "Point of Interest" -> 
          # Fallback to manual formatting for types not in the mapping
          type
          |> String.replace("_", " ")
          |> String.split(" ")
          |> Enum.map(&String.capitalize/1)
          |> Enum.join(" ")
        readable_type -> readable_type
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_fallback_category([]), do: "attraction"
  defp get_fallback_category(place_types) when is_list(place_types) do
    cond do
      "restaurant" in place_types or "food" in place_types -> "restaurant"
      "lodging" in place_types -> "lodging"
      "beach" in place_types or "natural_feature" in place_types -> "beach"
      "park" in place_types or "national_park" in place_types -> "park"
      "bar" in place_types or "night_club" in place_types -> "nightlife"
      "shopping_mall" in place_types or "store" in place_types -> "shopping"
      "gas_station" in place_types -> "gas_station"
      true -> "attraction"
    end
  end
  defp get_fallback_category(_), do: "attraction"
  
  defp get_place_image(poi) do
    case Map.get(poi, :photos) do
      [first_photo | _] when is_map(first_photo) ->
        photo_ref = Map.get(first_photo, "photo_reference")
        if photo_ref do
          maps_api_key = System.get_env("GOOGLE_MAPS_API_KEY")
          "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=#{photo_ref}&key=#{maps_api_key}"
        else
          get_fallback_image(poi)
        end
      _ ->
        get_fallback_image(poi)
    end
  end
  
  defp get_fallback_image(poi) do
    category = get_fallback_category(Map.get(poi, :place_types, []))
    case category do
      "restaurant" -> "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop"
      "gas_station" -> "https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=400&h=300&fit=crop"
      "lodging" -> "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=300&fit=crop"
      "shopping" -> "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop"
      "beach" -> "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&h=300&fit=crop"
      "park" -> "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop"
      "attraction" -> "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop"
      _ -> "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop"
    end
  end
  
  defp get_opening_status(poi) do
    case Map.get(poi, :opening_hours) do
      %{"open_now" => open_now} when is_boolean(open_now) -> open_now
      %{open_now: open_now} when is_boolean(open_now) -> open_now
      _ -> nil
    end
  end
  
  defp get_photo_array(poi) do
    case Map.get(poi, :photos) do
      photos when is_list(photos) -> photos
      _ -> []
    end
  end
  
  defp get_simplified_google_data(poi) do
    case Map.get(poi, :google_data) do
      %{} = google_data ->
        %{
          businessStatus: Map.get(google_data, "business_status"),
          editorialSummary: get_in(google_data, ["editorial_summary", "overview"]),
          internationalPhoneNumber: Map.get(google_data, "international_phone_number"),
          url: Map.get(google_data, "url"),
          utcOffset: Map.get(google_data, "utc_offset"),
          vicinity: Map.get(google_data, "vicinity"),
          wheelchair_accessible_entrance: Map.get(google_data, "wheelchair_accessible_entrance")
        }
        |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
        |> Map.new()
      _ -> %{}
    end
  end
  
  defp get_simplified_location_iq_data(poi) do
    case Map.get(poi, :location_iq_data) do
      %{} = location_iq_data ->
        %{
          displayName: Map.get(location_iq_data, "display_name"),
          class: Map.get(location_iq_data, "class"),
          type: Map.get(location_iq_data, "type"),
          importance: Map.get(location_iq_data, "importance"),
          addressType: Map.get(location_iq_data, "addresstype")
        }
        |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
        |> Map.new()
      _ -> %{}
    end
  end
  
  defp determine_data_source(poi) do
    cond do
      Map.get(poi, :google_place_id) -> "google_places"
      Map.get(poi, :location_iq_place_id) -> "location_iq"
      Map.get(poi, :tripadvisor_url) -> "tripadvisor"
      true -> "manual"
    end
  end
  
  defp generate_poi_images(poi_id) do
    ImageService.get_poi_image_set(poi_id)
  end
  
  defp generate_category_icon_url(category) do
    ImageService.get_category_icon_url(category)
  end
  
  
end