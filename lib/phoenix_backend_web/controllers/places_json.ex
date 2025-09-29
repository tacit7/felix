defmodule RouteWiseApiWeb.PlacesJSON do
  import RouteWiseApiWeb.CacheHelpers
  alias RouteWiseApi.Places.Place

  @doc """
  Renders a list of places for search results.
  """
  def search(%{places: places} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        places: for(place <- places, do: place_summary(place)),
        count: length(places)
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders detailed place information.
  """
  def details(%{place: place} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        place: place_details(place)
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders hybrid autocomplete results from multiple sources.
  """
  def hybrid_autocomplete(%{suggestions: suggestions} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        suggestions: for(suggestion <- suggestions, do: format_hybrid_suggestion(suggestion)),
        count: length(suggestions),
        sources_used: get_sources_used(suggestions)
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders smart autocomplete with mixed result types.
  """
  def smart_autocomplete(%{suggestions: response} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        suggestions: response.suggestions,
        count: response.count,
        input: response.input,
        detected_types: response.detected_types
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders legacy autocomplete suggestions (Google Places only).
  """
  def autocomplete(%{suggestions: suggestions} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        suggestions: suggestions,
        count: length(suggestions)
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders unified autocomplete suggestions for addresses, cities, regions, and places.
  """
  def unified_autocomplete(%{suggestions: suggestions} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        input: suggestions.input,
        types_requested: suggestions.types_requested,
        suggestions: suggestions.suggestions,
        total_count: suggestions.total_count,
        breakdown: build_count_breakdown(suggestions.suggestions)
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders nearby places results.
  """
  def nearby(%{places: places} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        places: for(place <- places, do: place_summary(place)),
        count: length(places)
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders photo URL.
  """
  def photo(%{photo_url: photo_url} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",  
      data: %{
        photo_url: photo_url
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders city autocomplete results.
  """
  def city_autocomplete(%{results: results} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: %{
        cities: results,
        count: length(results)
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders LocationIQ monitoring dashboard.
  """
  def locationiq_status(%{dashboard: dashboard} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      status: "success",
      data: dashboard
    }
    |> maybe_add_cache_meta(cache_info)
  end

  # Private helper functions

  defp place_summary(%Place{} = place) do
    %{
      id: place.id,
      google_place_id: place.google_place_id,
      name: place.name,
      formatted_address: place.formatted_address,
      location: location_data(place),
      rating: format_decimal(place.rating),
      price_level: place.price_level,
      categories: place.categories,
      photos: format_photos(place.photos),
      cached_at: place.cached_at,
      tripadvisor_url: place.tripadvisor_url
    }
  end

  defp place_details(%Place{} = place) do
    %{
      id: place.id,
      google_place_id: place.google_place_id,
      name: place.name,
      formatted_address: place.formatted_address,
      location: location_data(place),
      rating: format_decimal(place.rating),
      price_level: place.price_level,
      categories: place.categories,
      phone_number: place.phone_number,
      website: place.website,
      opening_hours: place.opening_hours,
      photos: format_photos(place.photos),
      reviews_count: place.reviews_count,
      cached_at: place.cached_at,
      inserted_at: place.inserted_at,
      updated_at: place.updated_at,
      tripadvisor_url: place.tripadvisor_url
    }
  end

  defp location_data(%Place{latitude: lat, longitude: lng}) when not is_nil(lat) and not is_nil(lng) do
    %{
      latitude: format_decimal(lat),
      longitude: format_decimal(lng)
    }
  end
  defp location_data(_), do: nil

  defp format_decimal(nil), do: nil
  defp format_decimal(decimal) when is_struct(decimal, Decimal) do
    Decimal.to_float(decimal)
  end
  defp format_decimal(value), do: value

  defp format_photos(nil), do: []
  defp format_photos(photos) when is_list(photos) do
    Enum.map(photos, fn photo ->
      %{
        photo_reference: photo["photo_reference"],
        width: photo["width"],
        height: photo["height"],
        html_attributions: photo["html_attributions"] || []
      }
    end)
  end
  defp format_photos(_), do: []

  defp build_count_breakdown(suggestions_map) do
    suggestions_map
    |> Enum.map(fn {type, suggestions} ->
      {type, length(suggestions)}
    end)
    |> Enum.into(%{})
  end

  # Hybrid autocomplete helper functions
  defp format_hybrid_suggestion(suggestion) do
    %{
      id: suggestion.id,
      name: suggestion.name,
      display_name: Map.get(suggestion, :display_name),
      lat: suggestion.lat,
      lon: suggestion.lon,
      type: suggestion.type,
      type_name: place_type_name(suggestion.type),
      country_code: Map.get(suggestion, :country_code),
      admin1_code: Map.get(suggestion, :admin1_code),
      address: Map.get(suggestion, :address),
      source: suggestion.source,
      popularity_score: Map.get(suggestion, :popularity_score)
    }
    |> compact_suggestion()
  end

  defp get_sources_used(suggestions) do
    suggestions
    |> Enum.map(&(&1.source))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp place_type_name(1), do: "country"
  defp place_type_name(2), do: "region"
  defp place_type_name(3), do: "city"
  defp place_type_name(5), do: "poi"
  defp place_type_name(_), do: "unknown"

  defp compact_suggestion(suggestion) do
    # Remove nil values to keep response clean
    suggestion
    |> Enum.filter(fn {_key, value} -> !is_nil(value) end)
    |> Enum.into(%{})
  end
end