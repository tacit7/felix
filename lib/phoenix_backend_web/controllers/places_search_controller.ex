defmodule RouteWiseApiWeb.PlacesSearchController do
  use RouteWiseApiWeb, :controller
  
  alias RouteWiseApi.PlacesSearch
  require Logger

  @doc """
  Universal search endpoint with intelligent query parsing.
  
  GET /api/search?q=coffee+shops&lat=40.7831&lng=-73.9712&radius=2000
  """
  def universal_search(conn, params) do
    query_text = params["q"] || ""
    
    # Parse location
    location = parse_location(params)
    
    # Build search options
    search_opts = %{
      location: location,
      radius: parse_integer(params["radius"], 5000),
      categories: parse_categories(params["categories"]),
      min_rating: parse_float(params["min_rating"], nil),
      limit: parse_integer(params["limit"], 20),
      sort_by: parse_sort_by(params["sort"])
    }
    
    try do
      results = PlacesSearch.search(query_text, search_opts)
      
      Logger.info("🔍 Universal search: '#{query_text}' found #{length(results)} results")
      
      json(conn, %{
        success: true,
        data: %{
          results: format_search_results(results),
          query: query_text,
          location: location,
          total_found: length(results),
          search_options: search_opts
        },
        meta: build_search_meta(results, search_opts),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
      
    rescue
      error ->
        Logger.error("Search error: #{Exception.message(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: %{
            message: "Search failed",
            code: "SEARCH_ERROR"
          }
        })
    end
  end

  @doc """
  Fast autocomplete suggestions.
  
  GET /api/search/autocomplete?q=centr&limit=5
  """
  def autocomplete(conn, params) do
    query_text = String.trim(params["q"] || "")
    
    if String.length(query_text) < 2 do
      json(conn, %{
        success: true,
        data: %{suggestions: []},
        message: "Query too short"
      })
    else
      location = parse_location(params)
      limit = parse_integer(params["limit"], 10)
      
      suggestions = PlacesSearch.autocomplete(query_text, %{
        location: location,
        limit: limit
      })
      
      json(conn, %{
        success: true,
        data: %{
          suggestions: format_autocomplete_results(suggestions),
          query: query_text
        }
      })
    end
  end

  @doc """
  Category-based search.
  
  GET /api/search/category/restaurant?lat=40.7831&lng=-73.9712
  """
  def search_category(conn, %{"category" => category} = params) do
    location = parse_location(params)
    
    if is_nil(location) do
      conn
      |> put_status(:bad_request)
      |> json(%{
        success: false,
        error: %{message: "Location (lat, lng) required for category search"}
      })
    else
      radius = parse_integer(params["radius"], 5000)
      limit = parse_integer(params["limit"], 15)
      min_rating = parse_float(params["min_rating"], 3.0)
      
      results = PlacesSearch.search_by_category(category, location, radius, %{
        limit: limit,
        min_rating: min_rating
      })
      
      json(conn, %{
        success: true,
        data: %{
          results: format_search_results(results),
          category: category,
          location: location,
          total_found: length(results)
        }
      })
    end
  end

  @doc """
  Popular places in an area.
  
  GET /api/search/popular?lat=40.7831&lng=-73.9712&radius=10000
  """
  def popular_places(conn, params) do
    location = parse_location(params)
    
    if is_nil(location) do
      conn
      |> put_status(:bad_request)
      |> json(%{
        success: false,
        error: %{message: "Location (lat, lng) required"}
      })
    else
      radius = parse_integer(params["radius"], 10000)
      limit = parse_integer(params["limit"], 20)
      min_rating = parse_float(params["min_rating"], 4.0)
      
      results = PlacesSearch.popular_places(location, radius, %{
        limit: limit,
        min_rating: min_rating
      })
      
      json(conn, %{
        success: true,
        data: %{
          results: format_search_results(results),
          location: location,
          total_found: length(results)
        }
      })
    end
  end

  @doc """
  Find similar places to a given place.
  
  GET /api/search/similar/123
  """
  def similar_places(conn, %{"place_id" => place_id}) do
    case Integer.parse(place_id) do
      {id, ""} ->
        limit = parse_integer(conn.params["limit"], 10)
        results = PlacesSearch.find_similar(id, %{limit: limit})
        
        json(conn, %{
          success: true,
          data: %{
            results: format_search_results(results),
            reference_place_id: id,
            total_found: length(results)
          }
        })
        
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: %{message: "Invalid place_id"}
        })
    end
  end

  # Private helper functions

  defp parse_location(%{"lat" => lat_str, "lng" => lng_str}) when is_binary(lat_str) and is_binary(lng_str) do
    with {lat, ""} <- Float.parse(lat_str),
         {lng, ""} <- Float.parse(lng_str) do
      %{lat: lat, lng: lng}
    else
      _ -> nil
    end
  end
  defp parse_location(%{"lat" => lat, "lng" => lng}) when is_number(lat) and is_number(lng) do
    %{lat: lat, lng: lng}
  end
  defp parse_location(_), do: nil

  defp parse_integer(nil, default), do: default
  defp parse_integer(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _ -> default
    end
  end
  defp parse_integer(num, _default) when is_integer(num), do: num
  defp parse_integer(_, default), do: default

  defp parse_float(nil, default), do: default
  defp parse_float(str, default) when is_binary(str) do
    case Float.parse(str) do
      {num, ""} -> num
      _ -> default
    end
  end
  defp parse_float(num, _default) when is_number(num), do: num
  defp parse_float(_, default), do: default

  defp parse_categories(nil), do: []
  defp parse_categories(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
  defp parse_categories(list) when is_list(list), do: list
  defp parse_categories(_), do: []

  defp parse_sort_by("distance"), do: :distance
  defp parse_sort_by("rating"), do: :rating
  defp parse_sort_by("popularity"), do: :popularity
  defp parse_sort_by("relevance"), do: :relevance
  defp parse_sort_by(_), do: :relevance

  defp format_search_results(results) do
    Enum.map(results, &format_search_result/1)
  end

  defp format_search_result(place) do
    %{
      id: place.id,
      name: place.name,
      description: place.description,
      address: place.formatted_address,
      coordinates: %{
        lat: format_coordinate(place.latitude),
        lng: format_coordinate(place.longitude)
      },
      categories: place.categories || [],
      rating: format_rating(place.rating),
      price_level: place.price_level,
      review_count: place.reviews_count || 0,
      popularity_score: place.popularity_score || 0,
      contact: %{
        phone: place.phone_number,
        website: place.website
      },
      opening_hours: place.opening_hours,
      photos: format_photos(place.photos),
      
      # Search-specific fields
      distance_km: Map.get(place, :distance_km),
      relevance_score: Map.get(place, :relevance_score),
      
      # API identifiers
      google_place_id: place.google_place_id,
      location_iq_place_id: place.location_iq_place_id,
      
      # Metadata
      cached_at: place.cached_at,
      last_updated: format_datetime(place.updated_at)
    }
  end

  defp format_autocomplete_results(suggestions) do
    Enum.map(suggestions, fn suggestion ->
      %{
        id: suggestion.id,
        name: suggestion.name,
        address: suggestion.formatted_address,
        categories: suggestion.categories || [],
        rating: format_rating(suggestion.rating),
        coordinates: %{
          lat: format_coordinate(suggestion.latitude),
          lng: format_coordinate(suggestion.longitude)
        }
      }
    end)
  end

  defp format_coordinate(nil), do: nil
  defp format_coordinate(%Decimal{} = coord), do: Decimal.to_float(coord)
  defp format_coordinate(coord) when is_number(coord), do: coord

  defp format_rating(nil), do: nil
  defp format_rating(%Decimal{} = rating), do: Decimal.to_float(rating)
  defp format_rating(rating) when is_number(rating), do: rating

  defp format_photos(nil), do: []
  defp format_photos(photos) when is_list(photos) do
    Enum.take(photos, 3)  # Limit to first 3 photos
  end
  defp format_photos(_), do: []

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC") |> DateTime.to_iso8601()

  defp build_search_meta(results, search_opts) do
    %{
      result_count: length(results),
      search_radius_km: (search_opts[:radius] || 5000) / 1000,
      has_location_filter: !is_nil(search_opts[:location]),
      has_category_filter: !Enum.empty?(search_opts[:categories] || []),
      sorting: search_opts[:sort_by] || :relevance,
      performance: %{
        cached_results: Enum.count(results, & &1.cached_at),
        fresh_results: length(results) - Enum.count(results, & &1.cached_at)
      }
    }
  end
end