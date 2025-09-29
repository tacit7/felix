defmodule RouteWiseApi.Places do
  @moduledoc """
  The Places context for managing place data and Google Places API integration.
  """

  import Ecto.Query, warn: false
  require Logger
  alias RouteWiseApi.Repo
  alias RouteWiseApi.Places.Place
  alias RouteWiseApi.Places.PlaceNearby
  alias RouteWiseApi.Places.Location
  alias RouteWiseApi.Places.CachedPlace

  @doc """
  Returns the list of places.

  ## Examples

      iex> list_places()
      [%Place{}, ...]

  """
  def list_places do
    Repo.all(Place)
  end

  @doc """
  Gets a single place by ID.

  Raises `Ecto.NoResultsError` if the Place does not exist.

  ## Examples

      iex> get_place!(123)
      %Place{}

      iex> get_place!("invalid")
      ** (Ecto.NoResultsError)

  """
  def get_place!(id), do: Repo.get!(Place, id)

  @doc """
  Query POIs within geographic bounds with optional filters.
  
  Optimized for POI clustering with spatial indexing.
  
  ## Parameters
  - south, north: Latitude bounds
  - west, east: Longitude bounds  
  - filters: %{categories: [string], min_rating: float}
  
  ## Examples
  
      iex> query_pois_in_bounds(30.0, 31.0, -98.0, -97.0)
      {:ok, [%Place{}, ...]}
      
      iex> query_pois_in_bounds(30.0, 31.0, -98.0, -97.0, %{categories: ["restaurant"], min_rating: 4.0})
      {:ok, [%Place{}, ...]}
  """
  def query_pois_in_bounds(south, north, west, east, filters \\ %{}) do
    try do
      query = from p in Place,
        where: p.latitude >= ^south and p.latitude <= ^north,
        where: p.longitude >= ^west and p.longitude <= ^east,
        where: not is_nil(p.latitude) and not is_nil(p.longitude)
      
      # Add category filter
      query = if Map.has_key?(filters, :categories) do
        categories = Map.get(filters, :categories)
        from p in query, where: p.category in ^categories
      else
        query
      end
      
      # Add rating filter
      query = if Map.has_key?(filters, :min_rating) do
        min_rating = Map.get(filters, :min_rating)
        from p in query, where: p.rating >= ^min_rating
      else
        query
      end
      
      # Limit results for performance (clustering will handle aggregation)
      query = from p in query, 
        limit: 1000,
        order_by: [desc: p.rating]
      
      pois = Repo.all(query)
      {:ok, pois}
    rescue
      error ->
        Logger.error("Failed to query POIs in bounds: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  @doc """
  Gets a single place by ID.

  Returns nil if the Place does not exist.

  ## Examples

      iex> get_place(123)
      %Place{}

      iex> get_place("invalid")
      nil

  """
  def get_place(id), do: Repo.get(Place, id)

  @doc """
  Gets a place by Google Place ID.

  ## Examples

      iex> get_place_by_google_id("ChIJN1t_tDeuEmsRUsoyG83frY4")
      %Place{}

      iex> get_place_by_google_id("nonexistent")
      nil

  """
  def get_place_by_google_id(google_place_id) when is_binary(google_place_id) do
    Repo.get_by(Place, google_place_id: google_place_id)
  end

  @doc """
  Gets a place by LocationIQ Place ID.

  ## Examples

      iex> get_place_by_location_iq_id("12345")
      %Place{}

      iex> get_place_by_location_iq_id("nonexistent")
      nil

  """
  def get_place_by_location_iq_id(location_iq_place_id) when is_binary(location_iq_place_id) do
    Repo.get_by(Place, location_iq_place_id: location_iq_place_id)
  end

  @doc """
  Creates a place from Google Places API data.

  ## Examples

      iex> create_place_from_google(google_data)
      {:ok, %Place{}}

      iex> create_place_from_google(invalid_data)
      {:error, %Ecto.Changeset{}}

  """
  def create_place_from_google(google_data) do
    google_data
    |> Place.from_google_response()
    |> create_place()
  end

  @doc """
  Creates a place from LocationIQ API data.

  ## Examples

      iex> create_place_from_location_iq(location_iq_data)
      {:ok, %Place{}}

      iex> create_place_from_location_iq(invalid_data)
      {:error, %Ecto.Changeset{}}

  """
  def create_place_from_location_iq(location_iq_data) do
    location_iq_data
    |> Place.from_location_iq_response()
    |> create_place()
  end

  @doc """
  Creates a place.

  ## Examples

      iex> create_place(%{field: value})
      {:ok, %Place{}}

      iex> create_place(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_place(attrs \\ %{}) do
    %Place{}
    |> Place.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a place.

  ## Examples

      iex> update_place(place, %{field: new_value})
      {:ok, %Place{}}

      iex> update_place(place, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_place(%Place{} = place, attrs) do
    place
    |> Place.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates or creates a place from Google Places API data.

  ## Examples

      iex> upsert_place_from_google(google_data)
      {:ok, %Place{}}

  """
  def upsert_place_from_google(google_data) do
    place_attrs = Place.from_google_response(google_data)
    google_place_id = place_attrs.google_place_id

    case get_place_by_google_id(google_place_id) do
      nil ->
        create_place(place_attrs)

      existing_place ->
        update_place(existing_place, place_attrs)
    end
  end

  @doc """
  Updates or creates a place from LocationIQ API data.

  ## Examples

      iex> upsert_place_from_location_iq(location_iq_data)
      {:ok, %Place{}}

  """
  def upsert_place_from_location_iq(location_iq_data) do
    place_attrs = Place.from_location_iq_response(location_iq_data)
    location_iq_place_id = place_attrs.location_iq_place_id

    case get_place_by_location_iq_id(location_iq_place_id) do
      nil ->
        create_place(place_attrs)

      existing_place ->
        update_place(existing_place, place_attrs)
    end
  end

  @doc """
  Deletes a place.

  ## Examples

      iex> delete_place(place)
      {:ok, %Place{}}

      iex> delete_place(place)
      {:error, %Ecto.Changeset{}}

  """
  def delete_place(%Place{} = place) do
    Repo.delete(place)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking place changes.

  ## Examples

      iex> change_place(place)
      %Ecto.Changeset{data: %Place{}}

  """
  def change_place(%Place{} = place, attrs \\ %{}) do
    Place.changeset(place, attrs)
  end

  @doc """
  Searches for places by location and query.

  ## Examples

      iex> search_places_near(%{lat: 37.7749, lng: -122.4194}, "restaurant")
      [%Place{}, ...]

  """
  def search_places_near(location, query \\ nil, radius \\ 5000) do
    base_query = from p in Place

    query =
      if query do
        from p in base_query,
          where: ilike(p.name, ^"%#{query}%") or ilike(p.formatted_address, ^"%#{query}%")
      else
        base_query
      end

    # Add location-based filtering using bounding box for performance
    # This is a simplified approach - for production, consider PostGIS
    lat_delta = radius / 111_320  # Approximate meters per degree latitude
    lng_delta = radius / (111_320 * :math.cos(location.lat * :math.pi() / 180))

    query
    |> where([p], p.latitude >= ^(location.lat - lat_delta))
    |> where([p], p.latitude <= ^(location.lat + lat_delta))
    |> where([p], p.longitude >= ^(location.lng - lng_delta))
    |> where([p], p.longitude <= ^(location.lng + lng_delta))
    |> order_by([p], desc: p.curated, desc: p.rating, desc: p.reviews_count)  # Prioritize curated places first
    |> preload(:default_image)
    |> Repo.all()
  end

  @doc """
  Gets POIs within a bounding box for clustering analysis.

  Optimized for the POI clustering system with consistent coordinate format
  and efficient spatial filtering using bounding box queries.

  ## Parameters

  - `bounds` - Map with :north, :south, :east, :west coordinates
  - `filters` - Optional filters map (categories, min_rating, etc.)

  ## Returns

  List of place maps with :id, :lat, :lng, :category, :rating fields
  optimized for clustering calculations.

  ## Examples

      bounds = %{north: 30.3322, south: 30.2672, east: -97.7431, west: -97.7731}
      pois = get_pois_in_bounds(bounds, %{categories: ["restaurant"], min_rating: 4.0})

  """
  def get_pois_in_bounds(bounds, filters \\ %{}) do
    base_query = from p in Place,
      where: p.latitude >= ^bounds.south,
      where: p.latitude <= ^bounds.north,
      where: p.longitude >= ^bounds.west,
      where: p.longitude <= ^bounds.east,
      select: %{
        id: p.id,
        lat: p.latitude,
        lng: p.longitude,
        name: p.name,
        category: fragment("?[1]", p.categories),  # Get first place type as category
        rating: p.rating,
        reviews_count: p.reviews_count,
        categories: p.categories,
        formatted_address: p.formatted_address,
        price_level: p.price_level
      }

    query = apply_poi_filters(base_query, filters)
    
    query
    |> order_by([p], desc: p.rating, desc: p.reviews_count)
    |> limit(1000)  # Reasonable limit for clustering performance
    |> Repo.all()
    |> Enum.map(&normalize_poi_coordinates/1)
  end

  # Apply various filters to the POI query
  defp apply_poi_filters(query, filters) when filters == %{}, do: query
  
  defp apply_poi_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:categories, categories}, acc ->
        if is_list(categories) do
          from p in acc,
            where: fragment("? && ?", p.categories, ^categories)
        else
          acc
        end
      
      {:min_rating, min_rating}, acc ->
        if is_number(min_rating) do
          from p in acc, where: p.rating >= ^min_rating
        else
          acc
        end
      
      {:price_levels, price_levels}, acc ->
        if is_list(price_levels) do
          from p in acc, where: p.price_level in ^price_levels
        else
          acc
        end
      
      {:has_reviews, true}, acc ->
        from p in acc, where: p.reviews_count > 0
      
      _other, acc -> acc  # Ignore unknown filters
    end)
  end

  # Ensure coordinates are floats for clustering calculations
  defp normalize_poi_coordinates(poi) do
    poi
    |> Map.update!(:lat, &decimal_to_float/1)
    |> Map.update!(:lng, &decimal_to_float/1)
  end

  defp decimal_to_float(value) when is_struct(value, Decimal), do: Decimal.to_float(value)
  defp decimal_to_float(value) when is_float(value), do: value
  defp decimal_to_float(value) when is_integer(value), do: value * 1.0

  @doc """
  Gets cached places by type within a location.

  ## Examples

      iex> get_places_by_type(%{lat: 37.7749, lng: -122.4194}, "restaurant")
      [%Place{}, ...]

  """
  def get_places_by_type(location, place_type, radius \\ 5000) do
    lat_delta = radius / 111_320
    lng_delta = radius / (111_320 * :math.cos(location.lat * :math.pi() / 180))

    from(p in Place,
      where: ^place_type in p.categories,
      where: p.latitude >= ^(location.lat - lat_delta),
      where: p.latitude <= ^(location.lat + lat_delta),
      where: p.longitude >= ^(location.lng - lng_delta),
      where: p.longitude <= ^(location.lng + lng_delta),
      order_by: [desc: p.rating, desc: p.reviews_count]
    )
    |> Repo.all()
  end

  @doc """
  Find nearby places using PostGIS geospatial search.
  
  This function uses PostGIS ST_DWithin for accurate distance-based searches,
  much faster than bounding box approximations for large datasets.
  
  ## Parameters
  
  - `location` - Map with :lat and :lng coordinates
  - `radius_meters` - Search radius in meters (default: 5000)
  - `filters` - Optional filters (categories, min_rating, etc.)
  - `limit` - Maximum results (default: 50)
  
  ## Examples
  
      location = %{lat: 30.2672, lng: -97.7431}  # Austin, TX
      places = find_nearby_places(location, 2000, %{categories: ["restaurant"]}, 20)
      
  ## Returns
  
  List of Place structs ordered by distance, then rating.
  """
  def find_nearby_places(location, radius_meters \\ 5000, filters \\ %{}, limit \\ 50) do
    point = %Geo.Point{coordinates: {location.lng, location.lat}, srid: 4326}
    
    base_query = from p in Place,
      where: fragment("ST_DWithin(?, ?, ?)", p.location, ^point, ^radius_meters),
      select: %{
        id: p.id,
        name: p.name,
        formatted_address: p.formatted_address,
        latitude: p.latitude,
        longitude: p.longitude,
        categories: p.categories,
        rating: p.rating,
        price_level: p.price_level,
        reviews_count: p.reviews_count,
        phone_number: p.phone_number,
        website: p.website,
        distance: fragment("ST_Distance(?, ?)", p.location, ^point)
      }
    
    query = apply_place_filters(base_query, filters)
    
    query
    |> order_by([p], asc: fragment("ST_Distance(?, ?)", p.location, ^point), desc: p.rating)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Find places within a bounding box using PostGIS.
  
  Efficient for map viewport searches where you need all places
  within the visible area.
  
  ## Parameters
  
  - `north`, `south`, `east`, `west` - Bounding box coordinates
  - `filters` - Optional filters map
  - `limit` - Maximum results (default: 100)
  
  ## Examples
  
      # Austin area bounding box
      places = find_places_in_bounds(30.3, 30.2, -97.7, -97.8, %{min_rating: 4.0})
      
  ## Returns
  
  List of Place structs ordered by rating and review count.
  """
  def find_places_in_bounds(north, south, east, west, filters \\ %{}, limit \\ 100) do
    # Create polygon for bounding box
    polygon = %Geo.Polygon{
      coordinates: [[
        {west, south}, {east, south}, {east, north}, {west, north}, {west, south}
      ]],
      srid: 4326
    }
    
    base_query = from p in Place,
      where: fragment("ST_Within(?, ?)", p.location, ^polygon),
      select: %{
        id: p.id,
        name: p.name,
        formatted_address: p.formatted_address,
        latitude: p.latitude,
        longitude: p.longitude,
        categories: p.categories,
        rating: p.rating,
        price_level: p.price_level,
        reviews_count: p.reviews_count,
        phone_number: p.phone_number,
        website: p.website
      }
    
    query = apply_place_filters(base_query, filters)
    
    query
    |> order_by([p], desc: p.rating, desc: p.reviews_count)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Find places near a route path using PostGIS buffer.
  
  Creates a buffer around a route polyline and finds places within
  the buffered corridor. Useful for "places along the way" features.
  
  ## Parameters
  
  - `polyline_points` - List of {lng, lat} coordinate tuples
  - `buffer_meters` - Buffer distance from route (default: 1000)
  - `filters` - Optional filters map
  - `limit` - Maximum results (default: 100)
  
  ## Examples
  
      route = [{-97.7431, 30.2672}, {-97.5431, 30.1672}]  # Austin to somewhere
      places = find_places_near_route(route, 2000, %{categories: ["gas_station"]})
      
  ## Returns
  
  List of Place structs ordered by rating.
  """
  def find_places_near_route(polyline_points, buffer_meters \\ 1000, filters \\ %{}, limit \\ 100) do
    # Create LineString from polyline points
    linestring = %Geo.LineString{coordinates: polyline_points, srid: 4326}
    
    base_query = from p in Place,
      where: fragment("ST_DWithin(?, ?, ?)", p.location, ^linestring, ^buffer_meters),
      select: %{
        id: p.id,
        name: p.name,
        formatted_address: p.formatted_address,
        latitude: p.latitude,
        longitude: p.longitude,
        categories: p.categories,
        rating: p.rating,
        price_level: p.price_level,
        reviews_count: p.reviews_count,
        phone_number: p.phone_number,
        website: p.website,
        distance_from_route: fragment("ST_Distance(?, ?)", p.location, ^linestring)
      }
    
    query = apply_place_filters(base_query, filters)
    
    query
    |> order_by([p], asc: fragment("ST_Distance(?, ?)", p.location, ^linestring), desc: p.rating)
    |> limit(^limit)
    |> Repo.all()
  end

  # Apply filters to place queries (shared by geospatial functions)
  defp apply_place_filters(query, filters) when filters == %{}, do: query
  
  defp apply_place_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:categories, types}, acc when is_list(types) ->
        from p in acc, where: fragment("? && ?", p.categories, ^types)
      
      {:place_type, type}, acc when is_binary(type) ->
        from p in acc, where: ^type in p.categories
        
      {:min_rating, rating}, acc when is_number(rating) ->
        from p in acc, where: p.rating >= ^rating
        
      {:price_levels, levels}, acc when is_list(levels) ->
        from p in acc, where: p.price_level in ^levels
        
      {:has_phone, true}, acc ->
        from p in acc, where: not is_nil(p.phone_number)
        
      {:has_website, true}, acc ->
        from p in acc, where: not is_nil(p.website)
        
      {:query, search_query}, acc when is_binary(search_query) ->
        from p in acc, 
          where: ilike(p.name, ^"%#{search_query}%") or 
                 ilike(p.formatted_address, ^"%#{search_query}%")
      
      _other, acc -> acc  # Ignore unknown filters
    end)
  end

  @doc """
  Cleans up old cached place data.

  ## Examples

      iex> cleanup_old_cache(hours: 48)
      {5, nil}

  """
  def cleanup_old_cache(hours: hours) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    from(p in Place, where: p.cached_at < ^cutoff_time)
    |> Repo.delete_all()
  end

  # City-related functions

  @doc """
  Normalize location input for consistent searching.
  
  Converts: "PeRto Rico" -> "puerto-rico"
  Converts: "San Juan, PR" -> "san-juan-pr"
  Converts: "New York City" -> "new-york-city"
  """
  def normalize_location_input(input) when is_binary(input) do
    input
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")  # Remove punctuation except spaces
    |> String.replace(~r/\s+/, "-")     # Replace spaces with dashes
    |> String.trim("-")                 # Remove leading/trailing dashes
  end
  def normalize_location_input(_), do: ""

  @doc """
  Searches for cities using database cache and LocationIQ API fallback.

  Implements intelligent caching by checking the database first for
  cached results. If insufficient results are found, falls back to
  LocationIQ API and stores new cities for future requests.

  ## Parameters
  - query: Search string (required)
  - opts: Keyword list of options
    - :limit - Maximum results (default: 10)
    - :countries - Country codes (default: "us,ca,mx") 
    - :min_results - Minimum cached results before API call (default: 3)

  ## Examples
      iex> search_cities("san francisco", limit: 5)
      {:ok, [%{name: "San Francisco", country: "United States", ...}]}

      iex> search_cities("nonexistent", limit: 10)
      {:error, "LocationIQ API error: 400"}

  ## Returns
  - `{:ok, cities}` - List of city maps with location data
  - `{:error, reason}` - Error string if both cache and API fail

  ## Cache Behavior
  Popular cities (high search_count) are returned first from the database.
  New cities are automatically stored and their search count is incremented.
  """
  def search_cities(query, opts \\ []) do
    # Database-only search with input normalization
    normalized_query = normalize_location_input(query)
    db_results = search_cities_in_db(query, normalized_query, opts)
    
    if length(db_results) > 0 do
      Logger.info("🏙️  Database-only city search found #{length(db_results)} results for: #{query} (normalized: #{normalized_query})")
      {:ok, format_city_results(db_results)}
    else
      Logger.info("🔍 No database results found for city: #{query} (normalized: #{normalized_query})")
      {:error, "No cities found in database for: #{query}"}
    end
  end

  @doc false
  def search_cities_in_db(original_query, normalized_query, opts) do
    limit = Keyword.get(opts, :limit, 10)
    countries = 
      Keyword.get(opts, :countries, "us,ca,mx,pr") 
      |> String.split(",")
      |> Enum.map(&String.trim/1)
    
    from(c in Location,
      where: ilike(c.name, ^"%#{original_query}%") or 
             ilike(c.display_name, ^"%#{original_query}%") or
             ilike(c.normalized_name, ^"%#{normalized_query}%"),
      where: c.country_code in ^countries,
      order_by: [desc: c.search_count, asc: c.name],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp store_and_update_cities(api_results) do
    Enum.map(api_results, fn result ->
      case get_or_create_city(result) do
        {:ok, city} -> 
          increment_search_count(city)
          format_city_result(city)
        {:error, _} -> 
          # Return API result if DB storage fails
          %{
            name: result.city || extract_name_from_display(result.display_name),
            display_name: result.display_name,
            lat: result.lat,
            lon: result.lon,
            type: result.type,
            state: result.state,
            country: result.country,
            country_code: result.country_code
          }
      end
    end)
  end

  defp get_or_create_city(api_result) do
    case Repo.get_by(Location, location_iq_place_id: api_result.place_id) do
      nil ->
        %Location{}
        |> Location.changeset(api_result_to_attrs(api_result))
        |> Repo.insert()
      existing_city ->
        {:ok, existing_city}
    end
  end

  defp increment_search_count(city) do
    city
    |> Location.changeset(%{
      search_count: city.search_count + 1,
      last_searched_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  defp api_result_to_attrs(api_result) do
    %{
      location_iq_place_id: api_result.place_id,
      name: api_result.city || extract_name_from_display(api_result.display_name),
      display_name: api_result.display_name,
      latitude: Decimal.new(to_string(api_result.lat)),
      longitude: Decimal.new(to_string(api_result.lon)),
      city_type: api_result.type,
      state: api_result.state,
      country: api_result.country,
      country_code: api_result.country_code
    }
  end

  defp extract_name_from_display(display_name) do
    display_name
    |> String.split(",")
    |> List.first()
    |> String.trim()
  end

  @doc false
  def format_city_results(cities) do
    Enum.map(cities, &format_city_result/1)
  end

  defp format_city_result(city) do
    %{
      id: city.id,
      place_id: city.location_iq_place_id,
      name: city.name,
      display_name: city.display_name,
      lat: Decimal.to_float(city.latitude),
      lon: Decimal.to_float(city.longitude),
      type: city.city_type,
      state: city.state,
      country: city.country,
      country_code: city.country_code,
      # Geographic bounds for search radius calculation
      bbox_north: city.bbox_north,
      bbox_south: city.bbox_south,
      bbox_east: city.bbox_east,
      bbox_west: city.bbox_west,
      search_radius_meters: city.search_radius_meters,
      bounds_source: city.bounds_source,
      bounds_updated_at: city.bounds_updated_at
    }
  end

  @doc """
  Searches for places by name only (for text-based searches).
  """
  def search_places_by_name(query, limit \\ 50) do
    from(p in Place,
      where: ilike(p.name, ^"%#{query}%") or 
             ilike(p.city, ^"%#{query}%") or
             ilike(p.address, ^"%#{query}%"),
      order_by: [desc: p.rating, desc: p.user_ratings_total],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Searches for places nearby with query filtering.
  """
  def search_places_nearby(lat, lng, radius, query \\ nil) do
    lat = if is_binary(lat), do: String.to_float(lat), else: lat
    lng = if is_binary(lng), do: String.to_float(lng), else: lng
    
    base_query = from p in Place,
      where: fragment("ST_DWithin(ST_Point(?, ?), ST_Point(?, ?), ?)", 
                     ^lng, ^lat, p.longitude, p.latitude, ^radius)

    query = if query && query != "" do
      from p in base_query,
        where: ilike(p.name, ^"%#{query}%") or ilike(p.address, ^"%#{query}%")
    else
      base_query
    end

    query
    |> order_by([p], [desc: p.rating, desc: p.user_ratings_total])
    |> limit(50)
    |> preload(:default_image)
    |> Repo.all()
  end

  @doc """
  Gets places added since a specific timestamp for real-time updates.
  """
  def get_places_added_since(location, since_datetime) do
    location_parts = String.split(location, ",")
    city = hd(location_parts) |> String.trim()
    
    from(p in Place,
      where: ilike(p.city, ^"%#{city}%") and p.inserted_at > ^since_datetime,
      order_by: [desc: p.inserted_at],
      limit: 20
    )
    |> Repo.all()
  end

  # Cached Places functions for autocomplete

  @doc """
  Search cached places for autocomplete with fuzzy matching.
  Returns results ordered by relevance and popularity.
  """
  def search_cached_places(query, limit \\ 10) do
    normalized_query = String.downcase(String.trim(query))
    
    # Prefix search for early matches
    prefix_query = from cp in CachedPlace,
      where: fragment("lower(?) LIKE ?", cp.name, ^"#{normalized_query}%"),
      order_by: [
        asc: cp.place_type,
        desc: cp.popularity_score,
        desc: cp.search_count,
        asc: cp.name
      ],
      limit: ^limit

    # If prefix search doesn't yield enough results, do fuzzy search
    prefix_results = Repo.all(prefix_query)
    
    if length(prefix_results) >= limit do
      prefix_results
    else
      remaining_limit = limit - length(prefix_results)
      
      fuzzy_query = from cp in CachedPlace,
        where: fragment("? % ?", cp.name, ^normalized_query) and
               not (fragment("lower(?) LIKE ?", cp.name, ^"#{normalized_query}%")),
        order_by: [
          asc: cp.place_type,
          desc: fragment("similarity(?, ?)", cp.name, ^normalized_query),
          desc: cp.popularity_score,
          asc: cp.name
        ],
        limit: ^remaining_limit
      
      fuzzy_results = Repo.all(fuzzy_query)
      prefix_results ++ fuzzy_results
    end
  end

  @doc """
  Create a new cached place entry.
  """
  def create_cached_place(attrs \\ %{}) do
    %CachedPlace{}
    |> CachedPlace.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a cached place entry.
  """
  def update_cached_place(%CachedPlace{} = cached_place, attrs) do
    cached_place
    |> CachedPlace.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Increment search count for a cached place (tracks popularity).
  """
  def increment_cached_place_usage(%CachedPlace{} = cached_place) do
    cached_place
    |> CachedPlace.increment_search_changeset()
    |> Repo.update()
  end

  @doc """
  Get cached place by exact name and type (for deduplication).
  """
  def get_cached_place_by_name_and_type(name, place_type) do
    from(cp in CachedPlace,
      where: fragment("lower(?)", cp.name) == ^String.downcase(name) and
             cp.place_type == ^place_type
    )
    |> Repo.one()
  end

  @doc """
  Bulk insert cached places from external APIs.
  """
  def bulk_insert_cached_places(places_data) do
    Repo.insert_all(CachedPlace, places_data, on_conflict: :nothing)
  end

  @doc """
  Get top cached places by search count (for analytics).
  """
  def get_popular_cached_places(limit \\ 50) do
    from(cp in CachedPlace,
      order_by: [desc: cp.search_count, desc: cp.popularity_score],
      limit: ^limit
    )
    |> Repo.all()
  end

  # Places Nearby functions

  @doc """
  Returns the list of nearby places for a specific place.

  ## Examples

      iex> list_nearby_places(place_id)
      [%PlaceNearby{}, ...]

  """
  def list_nearby_places(place_id, opts \\ []) do
    base_query = from pn in PlaceNearby,
      where: pn.place_id == ^place_id,
      preload: [:place]

    base_query
    |> PlaceNearby.filter_by_criteria(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single nearby place by ID.

  Raises `Ecto.NoResultsError` if the PlaceNearby does not exist.

  ## Examples

      iex> get_nearby_place!(123)
      %PlaceNearby{}

      iex> get_nearby_place!("invalid")
      ** (Ecto.NoResultsError)

  """
  def get_nearby_place!(id), do: Repo.get!(PlaceNearby, id)

  @doc """
  Gets a single nearby place by ID.

  Returns nil if the PlaceNearby does not exist.

  ## Examples

      iex> get_nearby_place(123)
      %PlaceNearby{}

      iex> get_nearby_place("invalid")
      nil

  """
  def get_nearby_place(id), do: Repo.get(PlaceNearby, id)

  @doc """
  Creates a nearby place recommendation.

  ## Examples

      iex> create_nearby_place(%{place_id: 1, nearby_place_name: "Austin", recommendation_reason: "Great music scene"})
      {:ok, %PlaceNearby{}}

      iex> create_nearby_place(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_nearby_place(attrs \\ %{}) do
    %PlaceNearby{}
    |> PlaceNearby.changeset(attrs)
    |> maybe_calculate_distance()
    |> Repo.insert()
  end

  @doc """
  Creates a nearby place recommendation with admin validation.

  ## Examples

      iex> create_nearby_place_admin(%{place_id: 1, nearby_place_name: "Austin", recommendation_reason: "Great music scene"})
      {:ok, %PlaceNearby{}}

  """
  def create_nearby_place_admin(attrs \\ %{}) do
    %PlaceNearby{}
    |> PlaceNearby.admin_changeset(attrs)
    |> maybe_calculate_distance()
    |> Repo.insert()
  end

  @doc """
  Updates a nearby place recommendation.

  ## Examples

      iex> update_nearby_place(nearby_place, %{recommendation_reason: "Updated reason"})
      {:ok, %PlaceNearby{}}

      iex> update_nearby_place(nearby_place, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_nearby_place(%PlaceNearby{} = nearby_place, attrs) do
    nearby_place
    |> PlaceNearby.changeset(attrs)
    |> maybe_calculate_distance()
    |> Repo.update()
  end

  @doc """
  Deletes a nearby place recommendation.

  ## Examples

      iex> delete_nearby_place(nearby_place)
      {:ok, %PlaceNearby{}}

      iex> delete_nearby_place(nearby_place)
      {:error, %Ecto.Changeset{}}

  """
  def delete_nearby_place(%PlaceNearby{} = nearby_place) do
    Repo.delete(nearby_place)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking nearby place changes.

  ## Examples

      iex> change_nearby_place(nearby_place)
      %Ecto.Changeset{data: %PlaceNearby{}}

  """
  def change_nearby_place(%PlaceNearby{} = nearby_place, attrs \\ %{}) do
    PlaceNearby.changeset(nearby_place, attrs)
  end

  @doc """
  Finds nearby places for a given place with optional filtering.

  ## Examples

      iex> find_nearby_places_for(place_id, %{category: "day_trip", max_distance_km: 100})
      [%PlaceNearby{}, ...]

  """
  def find_nearby_places_for(place_id, filters \\ %{}) do
    from(pn in PlaceNearby,
      where: pn.place_id == ^place_id and pn.is_active == true,
      preload: [:place]
    )
    |> PlaceNearby.filter_by_criteria(Map.to_list(filters))
    |> Repo.all()
  end

  @doc """
  Gets nearby places by recommendation category.

  ## Examples

      iex> get_nearby_places_by_category(place_id, "day_trip")
      [%PlaceNearby{}, ...]

  """
  def get_nearby_places_by_category(place_id, category) do
    from(pn in PlaceNearby,
      where: pn.place_id == ^place_id and
             pn.recommendation_category == ^category and
             pn.is_active == true,
      order_by: [asc: pn.sort_order, desc: pn.popularity_score],
      preload: [:place]
    )
    |> Repo.all()
  end

  @doc """
  Bulk insert nearby places recommendations.

  ## Examples

      iex> bulk_create_nearby_places([%{place_id: 1, nearby_place_name: "Austin", ...}, ...])
      {2, nil}

  """
  def bulk_create_nearby_places(nearby_places_data) do
    # Add timestamps and default values
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    places_with_timestamps = Enum.map(nearby_places_data, fn place_data ->
      place_data
      |> Map.put(:inserted_at, now)
      |> Map.put(:updated_at, now)
      |> Map.put_new(:is_active, true)
      |> Map.put_new(:sort_order, 0)
      |> Map.put_new(:verified, false)
      |> Map.put_new(:source, "manual")
    end)

    Repo.insert_all(PlaceNearby, places_with_timestamps, on_conflict: :nothing)
  end

  @doc """
  Search nearby places across all places by name or description.

  ## Examples

      iex> search_nearby_places("austin")
      [%PlaceNearby{}, ...]

  """
  def search_nearby_places(query, limit \\ 20) do
    normalized_query = "%#{String.downcase(String.trim(query))}%"

    from(pn in PlaceNearby,
      where: pn.is_active == true and
             (ilike(pn.nearby_place_name, ^normalized_query) or
              ilike(pn.description, ^normalized_query) or
              ilike(pn.recommendation_reason, ^normalized_query)),
      order_by: [desc: pn.popularity_score, asc: pn.nearby_place_name],
      limit: ^limit,
      preload: [:place]
    )
    |> Repo.all()
  end

  @doc """
  Get nearby places within a distance range from a specific place.

  ## Examples

      iex> get_nearby_places_within_distance(place_id, 50, 200)
      [%PlaceNearby{}, ...]

  """
  def get_nearby_places_within_distance(place_id, min_distance_km, max_distance_km) do
    from(pn in PlaceNearby,
      where: pn.place_id == ^place_id and
             pn.is_active == true and
             pn.distance_km >= ^min_distance_km and
             pn.distance_km <= ^max_distance_km,
      order_by: [asc: pn.distance_km, desc: pn.popularity_score],
      preload: [:place]
    )
    |> Repo.all()
  end

  @doc """
  Toggle active status of a nearby place.

  ## Examples

      iex> toggle_nearby_place_active(nearby_place)
      {:ok, %PlaceNearby{}}

  """
  def toggle_nearby_place_active(%PlaceNearby{} = nearby_place) do
    nearby_place
    |> PlaceNearby.changeset(%{is_active: !nearby_place.is_active})
    |> Repo.update()
  end

  @doc """
  Get statistics for nearby places recommendations.

  ## Examples

      iex> get_nearby_places_stats()
      %{total: 150, active: 140, categories: %{"day_trip" => 50, ...}}

  """
  def get_nearby_places_stats do
    total_query = from(pn in PlaceNearby, select: count(pn.id))
    active_query = from(pn in PlaceNearby, where: pn.is_active == true, select: count(pn.id))

    categories_query = from(pn in PlaceNearby,
      where: pn.is_active == true,
      group_by: pn.recommendation_category,
      select: {pn.recommendation_category, count(pn.id)}
    )

    place_types_query = from(pn in PlaceNearby,
      where: pn.is_active == true,
      group_by: pn.place_type,
      select: {pn.place_type, count(pn.id)}
    )

    %{
      total: Repo.one(total_query),
      active: Repo.one(active_query),
      categories: categories_query |> Repo.all() |> Enum.into(%{}),
      place_types: place_types_query |> Repo.all() |> Enum.into(%{})
    }
  end

  # Helper function to calculate distance if coordinates are provided
  defp maybe_calculate_distance(changeset) do
    place_id = Ecto.Changeset.get_field(changeset, :place_id)
    nearby_lat = Ecto.Changeset.get_field(changeset, :latitude)
    nearby_lng = Ecto.Changeset.get_field(changeset, :longitude)

    if place_id && nearby_lat && nearby_lng do
      case get_place(place_id) do
        %Place{latitude: place_lat, longitude: place_lng} when not is_nil(place_lat) and not is_nil(place_lng) ->
          distance = PlaceNearby.calculate_distance(place_lat, place_lng, nearby_lat, nearby_lng)
          Ecto.Changeset.put_change(changeset, :distance_km, distance)

        _ ->
          changeset
      end
    else
      changeset
    end
  end
end