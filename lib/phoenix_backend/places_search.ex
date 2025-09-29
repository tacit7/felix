defmodule RouteWiseApi.PlacesSearch do
  @moduledoc """
  Advanced search functionality for the places database using PostgreSQL full-text search,
  geospatial queries, and multi-criteria ranking.
  
  This module provides comprehensive search capabilities including:
  - Full-text search across names, addresses, descriptions
  - Geospatial proximity search
  - Category and rating filtering
  - Popularity-based ranking
  - Autocomplete suggestions
  """

  import Ecto.Query
  alias RouteWiseApi.{Repo, Places.Place}
  require Logger

  @doc """
  Main search function with multiple criteria.
  
  ## Options
  - `:query` - Text search query
  - `:location` - %{lat:, lng:} for proximity search
  - `:radius` - Search radius in meters (default: 5000)
  - `:categories` - List of place types to filter
  - `:min_rating` - Minimum rating (0.0-5.0)
  - `:limit` - Max results (default: 20)
  - `:sort_by` - :relevance, :distance, :rating, :popularity
  
  ## Examples
  
      # Text search with location
      PlacesSearch.search("coffee shops", %{
        location: %{lat: 40.7831, lng: -73.9712},
        radius: 2000,
        min_rating: 4.0,
        limit: 10
      })
      
      # Category search
      PlacesSearch.search("", %{
        location: %{lat: 40.7831, lng: -73.9712},
        categories: ["restaurant", "cafe"],
        sort_by: :popularity
      })
  """
  def search(query_text \\ "", opts \\ %{}) do
    location = opts[:location]
    radius = opts[:radius] || 5000
    categories = opts[:categories] || []
    min_rating = opts[:min_rating]
    limit = opts[:limit] || 20
    sort_by = opts[:sort_by] || :relevance

    Place
    |> apply_text_search(query_text)
    |> apply_location_filter(location, radius)
    |> apply_category_filter(categories)
    |> apply_rating_filter(min_rating)
    |> apply_sorting(sort_by, query_text, location)
    |> select_search_fields()
    |> limit(^limit)
    |> Repo.all()
    |> add_distance_and_relevance(query_text, location)
  end

  @doc """
  Fast autocomplete search for place names and addresses.
  
  ## Examples
  
      PlacesSearch.autocomplete("central park")
      # => [%{name: "Central Park", address: "New York, NY", ...}, ...]
  """
  def autocomplete(query_text, opts \\ %{}) do
    limit = opts[:limit] || 10
    location = opts[:location]

    base_query = from p in Place,
      where: fragment("? @@ plainto_tsquery('english', ?)", p.search_vector, ^query_text),
      or_where: ilike(p.name, ^"#{query_text}%"),
      select: %{
        id: p.id,
        name: p.name,
        formatted_address: p.formatted_address,
        categories: p.categories,
        rating: p.rating,
        latitude: p.latitude,
        longitude: p.longitude
      },
      order_by: [
        desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", p.search_vector, ^query_text),
        desc: p.popularity_score
      ],
      limit: ^limit

    query = if location do
      add_distance_ordering(base_query, location)
    else
      base_query
    end

    Repo.all(query)
  end

  @doc """
  Search places by category near a location.
  
  ## Examples
  
      PlacesSearch.search_by_category("restaurant", %{lat: 40.7831, lng: -73.9712}, 1000)
  """
  def search_by_category(category, location, radius \\ 5000, opts \\ %{}) do
    limit = opts[:limit] || 15
    min_rating = opts[:min_rating] || 3.0

    from(p in Place,
      where: ^category in p.categories,
      where: p.rating >= ^min_rating
    )
    |> apply_location_filter(location, radius)
    |> order_by([p], [desc: p.popularity_score, desc: p.rating])
    |> select_search_fields()
    |> limit(^limit)
    |> Repo.all()
    |> add_distance_and_relevance("", location)
  end

  @doc """
  Get popular places in a specific area.
  """
  def popular_places(location, radius \\ 10000, opts \\ %{}) do
    limit = opts[:limit] || 20
    min_rating = opts[:min_rating] || 4.0

    from(p in Place,
      where: p.rating >= ^min_rating,
      where: p.reviews_count > 10
    )
    |> apply_location_filter(location, radius)
    |> order_by([p], [desc: p.popularity_score, desc: p.rating, desc: p.reviews_count])
    |> select_search_fields()
    |> limit(^limit)
    |> Repo.all()
    |> add_distance_and_relevance("", location)
  end

  @doc """
  Find similar places based on categories and characteristics.
  """
  def find_similar(place_id, opts \\ %{}) do
    limit = opts[:limit] || 10

    case Repo.get(Place, place_id) do
      nil -> []
      place ->
        from(p in Place,
          where: p.id != ^place_id,
          where: fragment("? && ?", p.categories, ^place.categories),
          where: fragment("abs(? - ?) <= 1.0", p.rating, ^place.rating)
        )
        |> order_by([p], [desc: p.popularity_score])
        |> select_search_fields()
        |> limit(^limit)
        |> Repo.all()
    end
  end

  # Private helper functions

  defp apply_text_search(query, ""), do: query
  defp apply_text_search(query, text) when byte_size(text) < 2, do: query
  defp apply_text_search(query, text) do
    from q in query,
      where: fragment("? @@ plainto_tsquery('english', ?)", q.search_vector, ^text)
  end

  defp apply_location_filter(query, nil, _radius), do: query
  defp apply_location_filter(query, location, radius) do
    # Use simple bounding box for now (PostGIS version would use ST_DWithin)
    lat_delta = radius / 111_320
    lng_delta = radius / (111_320 * :math.cos(location.lat * :math.pi() / 180))

    from q in query,
      where: q.latitude >= ^(location.lat - lat_delta),
      where: q.latitude <= ^(location.lat + lat_delta),
      where: q.longitude >= ^(location.lng - lng_delta),
      where: q.longitude <= ^(location.lng + lng_delta)
  end

  defp apply_category_filter(query, []), do: query
  defp apply_category_filter(query, categories) do
    from q in query,
      where: fragment("? && ?", q.categories, ^categories)
  end

  defp apply_rating_filter(query, nil), do: query
  defp apply_rating_filter(query, min_rating) do
    from q in query,
      where: q.rating >= ^min_rating
  end

  defp apply_sorting(query, :relevance, query_text, _location) when query_text != "" do
    from q in query,
      order_by: [
        desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", q.search_vector, ^query_text),
        desc: q.popularity_score,
        desc: q.rating
      ]
  end

  defp apply_sorting(query, :distance, _query_text, %{lat: lat, lng: lng}) do
    from q in query,
      order_by: [
        asc: fragment("(? - ?)^2 + (? - ?)^2", q.latitude, ^lat, q.longitude, ^lng),
        desc: q.rating
      ]
  end

  defp apply_sorting(query, :rating, _query_text, _location) do
    from q in query,
      order_by: [desc: q.rating, desc: q.reviews_count, desc: q.popularity_score]
  end

  defp apply_sorting(query, :popularity, _query_text, _location) do
    from q in query,
      order_by: [desc: q.popularity_score, desc: q.rating]
  end

  defp apply_sorting(query, _, _query_text, _location) do
    from q in query,
      order_by: [desc: q.popularity_score, desc: q.rating]
  end

  defp add_distance_ordering(query, %{lat: lat, lng: lng}) do
    from q in query,
      order_by: [
        asc: fragment("(? - ?)^2 + (? - ?)^2", q.latitude, ^lat, q.longitude, ^lng)
      ]
  end
  defp add_distance_ordering(query, _), do: query

  defp select_search_fields(query) do
    from q in query,
      select: %{
        id: q.id,
        name: q.name,
        description: q.description,
        formatted_address: q.formatted_address,
        latitude: q.latitude,
        longitude: q.longitude,
        categories: q.categories,
        rating: q.rating,
        price_level: q.price_level,
        reviews_count: q.reviews_count,
        popularity_score: q.popularity_score,
        phone_number: q.phone_number,
        website: q.website,
        opening_hours: q.opening_hours,
        photos: q.photos,
        google_place_id: q.google_place_id,
        location_iq_place_id: q.location_iq_place_id,
        cached_at: q.cached_at,
        inserted_at: q.inserted_at,
        updated_at: q.updated_at
      }
  end

  defp add_distance_and_relevance(results, _query_text, nil), do: results
  defp add_distance_and_relevance(results, query_text, location) do
    Enum.map(results, fn place ->
      distance = calculate_distance(location, %{lat: place.latitude, lng: place.longitude})
      relevance_score = calculate_relevance_score(place, query_text)
      
      place
      |> Map.put(:distance_km, Float.round(distance, 2))
      |> Map.put(:relevance_score, relevance_score)
    end)
  end

  defp calculate_distance(%{lat: lat1, lng: lng1}, %{lat: lat2, lng: lng2}) do
    # Haversine formula for distance calculation
    dlat = :math.pi() * (Decimal.to_float(lat2) - lat1) / 180
    dlng = :math.pi() * (Decimal.to_float(lng2) - lng1) / 180

    lat1_rad = :math.pi() * lat1 / 180
    lat2_rad = :math.pi() * Decimal.to_float(lat2) / 180

    a = :math.sin(dlat/2) * :math.sin(dlat/2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(dlng/2) * :math.sin(dlng/2)
    
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1-a))
    6371 * c  # Earth's radius in km
  end

  defp calculate_relevance_score(place, "") do
    # Base relevance on popularity when no search query
    place.popularity_score || 0
  end
  defp calculate_relevance_score(place, query_text) do
    # Simple relevance scoring based on text matches
    name_match = if String.contains?(String.downcase(place.name || ""), String.downcase(query_text)), do: 50, else: 0
    address_match = if String.contains?(String.downcase(place.formatted_address || ""), String.downcase(query_text)), do: 20, else: 0
    description_match = if String.contains?(String.downcase(place.description || ""), String.downcase(query_text)), do: 30, else: 0
    
    name_match + address_match + description_match + (place.popularity_score || 0)
  end
end