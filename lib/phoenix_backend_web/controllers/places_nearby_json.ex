defmodule RouteWiseApiWeb.PlacesNearbyJSON do
  alias RouteWiseApi.Places.PlaceNearby

  @doc """
  Renders a list of nearby places for a specific place.
  """
  def index(%{nearby_places: nearby_places}) do
    %{
      status: "success",
      data: %{
        nearby_places: for(nearby_place <- nearby_places, do: nearby_place_summary(nearby_place)),
        count: length(nearby_places)
      }
    }
  end

  @doc """
  Renders detailed nearby place information.
  """
  def show(%{nearby_place: nearby_place}) do
    %{
      status: "success",
      data: %{
        nearby_place: nearby_place_details(nearby_place)
      }
    }
  end

  @doc """
  Renders search results for nearby places.
  """
  def search(%{nearby_places: nearby_places, query: query}) do
    %{
      status: "success",
      data: %{
        query: query,
        nearby_places: for(nearby_place <- nearby_places, do: nearby_place_summary(nearby_place)),
        count: length(nearby_places)
      }
    }
  end

  @doc """
  Renders nearby places by category.
  """
  def by_category(%{nearby_places: nearby_places, category: category}) do
    %{
      status: "success",
      data: %{
        category: category,
        nearby_places: for(nearby_place <- nearby_places, do: nearby_place_summary(nearby_place)),
        count: length(nearby_places)
      }
    }
  end

  @doc """
  Renders nearby places by distance range.
  """
  def by_distance(%{nearby_places: nearby_places, min_distance: min_distance, max_distance: max_distance}) do
    %{
      status: "success",
      data: %{
        distance_range: %{
          min_km: min_distance,
          max_km: max_distance
        },
        nearby_places: for(nearby_place <- nearby_places, do: nearby_place_summary(nearby_place)),
        count: length(nearby_places)
      }
    }
  end

  @doc """
  Renders statistics for nearby places.
  """
  def stats(%{stats: stats}) do
    %{
      status: "success",
      data: %{
        statistics: %{
          total: stats.total,
          active: stats.active,
          categories: stats.categories,
          place_types: stats.place_types
        }
      }
    }
  end

  # Private helper functions

  defp nearby_place_summary(%PlaceNearby{} = nearby_place) do
    %{
      id: nearby_place.id,
      place_id: nearby_place.place_id,
      nearby_place_name: nearby_place.nearby_place_name,
      recommendation_reason: nearby_place.recommendation_reason,
      description: nearby_place.description,
      location: location_data(nearby_place),
      distance_km: format_decimal(nearby_place.distance_km),
      travel_time_minutes: nearby_place.travel_time_minutes,
      transportation_method: nearby_place.transportation_method,
      place_type: nearby_place.place_type,
      recommendation_category: nearby_place.recommendation_category,
      best_season: nearby_place.best_season,
      difficulty_level: nearby_place.difficulty_level,
      estimated_visit_duration: nearby_place.estimated_visit_duration,
      popularity_score: nearby_place.popularity_score,
      is_active: nearby_place.is_active,
      verified: nearby_place.verified,
      tips: nearby_place.tips || [],
      image_url: nearby_place.image_url,
      inserted_at: nearby_place.inserted_at,
      updated_at: nearby_place.updated_at
    }
    |> compact_response()
  end

  defp nearby_place_details(%PlaceNearby{} = nearby_place) do
    %{
      id: nearby_place.id,
      place_id: nearby_place.place_id,
      nearby_place_name: nearby_place.nearby_place_name,
      recommendation_reason: nearby_place.recommendation_reason,
      description: nearby_place.description,
      location: location_data(nearby_place),
      distance_km: format_decimal(nearby_place.distance_km),
      travel_time_minutes: nearby_place.travel_time_minutes,
      transportation_method: nearby_place.transportation_method,
      place_type: nearby_place.place_type,
      country_code: nearby_place.country_code,
      state_province: nearby_place.state_province,
      popularity_score: nearby_place.popularity_score,
      recommendation_category: nearby_place.recommendation_category,
      best_season: nearby_place.best_season,
      difficulty_level: nearby_place.difficulty_level,
      estimated_visit_duration: nearby_place.estimated_visit_duration,
      google_place_id: nearby_place.google_place_id,
      location_iq_place_id: nearby_place.location_iq_place_id,
      wikipedia_url: nearby_place.wikipedia_url,
      official_website: nearby_place.official_website,
      tips: nearby_place.tips || [],
      image_url: nearby_place.image_url,
      image_attribution: nearby_place.image_attribution,
      is_active: nearby_place.is_active,
      sort_order: nearby_place.sort_order,
      source: nearby_place.source,
      verified: nearby_place.verified,
      last_verified_at: nearby_place.last_verified_at,
      inserted_at: nearby_place.inserted_at,
      updated_at: nearby_place.updated_at,
      # Include main place information if preloaded
      main_place: format_main_place(nearby_place.place)
    }
    |> compact_response()
  end

  defp location_data(%PlaceNearby{latitude: lat, longitude: lng}) when not is_nil(lat) and not is_nil(lng) do
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

  defp format_main_place(%RouteWiseApi.Places.Place{} = place) do
    %{
      id: place.id,
      name: place.name,
      formatted_address: place.formatted_address,
      location: %{
        latitude: format_decimal(place.latitude),
        longitude: format_decimal(place.longitude)
      },
      rating: format_decimal(place.rating),
      categories: place.categories
    }
  end
  defp format_main_place(%Ecto.Association.NotLoaded{}), do: nil
  defp format_main_place(nil), do: nil
  defp format_main_place(_), do: nil

  defp compact_response(response) do
    # Remove nil values to keep response clean
    response
    |> Enum.filter(fn {_key, value} -> !is_nil(value) end)
    |> Enum.into(%{})
  end
end