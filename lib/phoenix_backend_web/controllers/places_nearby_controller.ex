defmodule RouteWiseApiWeb.PlacesNearbyController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Places
  alias RouteWiseApi.Places.PlaceNearby

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  List nearby places for a specific place.

  ## Parameters
  - place_id: Place ID to get nearby recommendations for (required)
  - category: Filter by recommendation category (optional)
  - place_type: Filter by place type (optional)
  - max_distance_km: Maximum distance in kilometers (optional)
  - season: Filter by best season to visit (optional)
  - active: Filter by active status (optional, default: true)
  - order_by: Sort order - distance, popularity, name (optional)

  ## Examples
  GET /api/places/:place_id/nearby
  GET /api/places/123/nearby?category=day_trip&max_distance_km=100
  """
  def index(conn, %{"place_id" => place_id} = params) do
    with {:ok, place_id} <- validate_integer(place_id),
         {:ok, filters} <- build_nearby_filters(params) do
      nearby_places = Places.list_nearby_places(place_id, filters)
      render(conn, :index, nearby_places: nearby_places)
    end
  end

  @doc """
  Show details of a specific nearby place recommendation.

  ## Parameters
  - id: Nearby place ID (required)

  ## Examples
  GET /api/places/nearby/456
  """
  def show(conn, %{"id" => id}) do
    with {:ok, id} <- validate_integer(id) do
      nearby_place = Places.get_nearby_place!(id)
      render(conn, :show, nearby_place: nearby_place)
    end
  end

  @doc """
  Create a new nearby place recommendation (requires authentication).

  ## Parameters
  - place_id: Main place ID (required)
  - nearby_place_name: Name of the nearby place (required)
  - recommendation_reason: Why this place is recommended (required)
  - description: Additional description (optional)
  - latitude: Latitude coordinates (optional)
  - longitude: Longitude coordinates (optional)
  - recommendation_category: Category like day_trip, base_city, etc. (optional)
  - place_type: Type like city, town, attraction, etc. (optional)
  - distance_km: Distance in kilometers (optional, auto-calculated if coordinates provided)
  - travel_time_minutes: Travel time in minutes (optional)
  - transportation_method: Method like driving, walking, etc. (optional)
  - best_season: Best season to visit (optional)
  - difficulty_level: Difficulty level (optional)
  - estimated_visit_duration: Suggested visit duration (optional)

  ## Examples
  POST /api/places/nearby
  Content-Type: application/json
  {
    "place_id": 123,
    "nearby_place_name": "Austin",
    "recommendation_reason": "Great music scene and food",
    "latitude": 30.2672,
    "longitude": -97.7431,
    "recommendation_category": "day_trip"
  }
  """
  def create(conn, params) do
    # Require authentication for creating recommendations
    current_user = conn.assigns[:current_user]
    unless current_user do
      {:error, {:unauthorized, "Authentication required to create nearby place recommendations"}}
    else
      with {:ok, attrs} <- validate_create_params(params) do
        case Places.create_nearby_place(attrs) do
          {:ok, nearby_place} ->
            conn
            |> put_status(:created)
            |> put_resp_header("location", ~p"/api/places/nearby/#{nearby_place}")
            |> render(:show, nearby_place: nearby_place)

          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, {:bad_request, changeset}}
        end
      end
    end
  end

  @doc """
  Create a new nearby place recommendation with admin validation (requires authentication).

  ## Examples
  POST /api/places/nearby/admin
  """
  def create_admin(conn, params) do
    # Require authentication for admin creation
    current_user = conn.assigns[:current_user]
    unless current_user do
      {:error, {:unauthorized, "Authentication required for admin operations"}}
    else
      with {:ok, attrs} <- validate_create_params(params) do
        case Places.create_nearby_place_admin(attrs) do
          {:ok, nearby_place} ->
            conn
            |> put_status(:created)
            |> put_resp_header("location", ~p"/api/places/nearby/#{nearby_place}")
            |> render(:show, nearby_place: nearby_place)

          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, {:bad_request, changeset}}
        end
      end
    end
  end

  @doc """
  Update a nearby place recommendation (requires authentication).

  ## Parameters
  Same as create, all fields optional for updates

  ## Examples
  PUT /api/places/nearby/456
  """
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]
    unless current_user do
      {:error, {:unauthorized, "Authentication required to update nearby place recommendations"}}
    else
      with {:ok, id} <- validate_integer(id),
           {:ok, attrs} <- validate_update_params(params) do
        nearby_place = Places.get_nearby_place!(id)

        case Places.update_nearby_place(nearby_place, attrs) do
          {:ok, updated_nearby_place} ->
            render(conn, :show, nearby_place: updated_nearby_place)

          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, {:bad_request, changeset}}
        end
      end
    end
  end

  @doc """
  Delete a nearby place recommendation (requires authentication).

  ## Examples
  DELETE /api/places/nearby/456
  """
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    unless current_user do
      {:error, {:unauthorized, "Authentication required to delete nearby place recommendations"}}
    else
      with {:ok, id} <- validate_integer(id) do
        nearby_place = Places.get_nearby_place!(id)

        case Places.delete_nearby_place(nearby_place) do
          {:ok, _deleted_nearby_place} ->
            send_resp(conn, :no_content, "")

          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, {:bad_request, changeset}}
        end
      end
    end
  end

  @doc """
  Search nearby places across all places by name or description.

  ## Parameters
  - q: Search query (required)
  - limit: Maximum results (optional, default: 20, max: 100)

  ## Examples
  GET /api/places/nearby/search?q=austin&limit=10
  """
  def search(conn, params) do
    with {:ok, query} <- validate_required_string(params, "q"),
         {:ok, limit} <- validate_limit(params) do
      nearby_places = Places.search_nearby_places(query, limit)
      render(conn, :search, nearby_places: nearby_places, query: query)
    end
  end

  @doc """
  Get nearby places by category for a specific place.

  ## Parameters
  - place_id: Place ID (required)
  - category: Recommendation category (required)

  ## Examples
  GET /api/places/123/nearby/category/day_trip
  """
  def by_category(conn, %{"place_id" => place_id, "category" => category}) do
    with {:ok, place_id} <- validate_integer(place_id),
         {:ok, category} <- validate_category(category) do
      nearby_places = Places.get_nearby_places_by_category(place_id, category)
      render(conn, :by_category, nearby_places: nearby_places, category: category)
    end
  end

  @doc """
  Get nearby places within a distance range.

  ## Parameters
  - place_id: Place ID (required)
  - min_distance: Minimum distance in km (required)
  - max_distance: Maximum distance in km (required)

  ## Examples
  GET /api/places/123/nearby/distance?min_distance=50&max_distance=200
  """
  def by_distance(conn, %{"place_id" => place_id} = params) do
    with {:ok, place_id} <- validate_integer(place_id),
         {:ok, min_distance} <- validate_distance(params, "min_distance"),
         {:ok, max_distance} <- validate_distance(params, "max_distance") do
      nearby_places = Places.get_nearby_places_within_distance(place_id, min_distance, max_distance)
      render(conn, :by_distance, nearby_places: nearby_places, min_distance: min_distance, max_distance: max_distance)
    end
  end

  @doc """
  Toggle active status of a nearby place (requires authentication).

  ## Examples
  PATCH /api/places/nearby/456/toggle
  """
  def toggle_active(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    unless current_user do
      {:error, {:unauthorized, "Authentication required to toggle nearby place status"}}
    else
      with {:ok, id} <- validate_integer(id) do
        nearby_place = Places.get_nearby_place!(id)

        case Places.toggle_nearby_place_active(nearby_place) do
          {:ok, updated_nearby_place} ->
            render(conn, :show, nearby_place: updated_nearby_place)

          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, {:bad_request, changeset}}
        end
      end
    end
  end

  @doc """
  Get statistics for nearby places recommendations.

  ## Examples
  GET /api/places/nearby/stats
  """
  def stats(conn, _params) do
    stats = Places.get_nearby_places_stats()
    render(conn, :stats, stats: stats)
  end

  # Private validation functions

  defp validate_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, ""} when int_val > 0 ->
        {:ok, int_val}
      _ ->
        {:error, {:bad_request, "Invalid integer value"}}
    end
  end
  defp validate_integer(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp validate_integer(_), do: {:error, {:bad_request, "Invalid integer value"}}

  defp validate_required_string(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) and byte_size(value) > 0 ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "#{key} is required and must be a non-empty string"}}
    end
  end

  defp validate_limit(params) do
    case Map.get(params, "limit") do
      nil -> {:ok, 20}
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_val, ""} when int_val > 0 and int_val <= 100 ->
            {:ok, int_val}
          _ ->
            {:error, {:bad_request, "limit must be between 1 and 100"}}
        end
      value when is_integer(value) and value > 0 and value <= 100 ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "limit must be between 1 and 100"}}
    end
  end

  defp validate_distance(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case Float.parse(value) do
          {float_val, ""} when float_val >= 0 ->
            {:ok, float_val}
          _ ->
            {:error, {:bad_request, "#{key} must be a valid non-negative number"}}
        end
      value when is_number(value) and value >= 0 ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "#{key} is required and must be a valid non-negative number"}}
    end
  end

  defp validate_category(category) do
    valid_categories = PlaceNearby.valid_recommendation_categories()
    if category in valid_categories do
      {:ok, category}
    else
      {:error, {:bad_request, "Invalid category. Valid categories: #{Enum.join(valid_categories, ", ")}"}}
    end
  end

  defp build_nearby_filters(params) do
    filters = []

    filters = maybe_add_filter(filters, params, "category", :category)
    filters = maybe_add_filter(filters, params, "place_type", :place_type)
    filters = maybe_add_filter(filters, params, "season", :season)
    filters = maybe_add_filter(filters, params, "order_by", :order_by)

    # Handle max_distance_km filter
    filters = case Map.get(params, "max_distance_km") do
      value when is_binary(value) ->
        case Float.parse(value) do
          {distance, ""} when distance > 0 ->
            Keyword.put(filters, :max_distance_km, distance)
          _ ->
            filters
        end
      value when is_number(value) and value > 0 ->
        Keyword.put(filters, :max_distance_km, value)
      _ ->
        filters
    end

    # Handle active filter (defaults to true)
    filters = case Map.get(params, "active") do
      "false" -> Keyword.put(filters, :active, false)
      false -> Keyword.put(filters, :active, false)
      _ -> Keyword.put(filters, :active, true)
    end

    {:ok, filters}
  end

  defp maybe_add_filter(filters, params, param_key, filter_key) do
    case Map.get(params, param_key) do
      value when is_binary(value) and byte_size(value) > 0 ->
        Keyword.put(filters, filter_key, value)
      _ ->
        filters
    end
  end

  defp validate_create_params(params) do
    attrs = %{}

    # Required fields
    with {:ok, place_id} <- validate_required_integer(params, "place_id"),
         {:ok, nearby_place_name} <- validate_required_string(params, "nearby_place_name"),
         {:ok, recommendation_reason} <- validate_required_string(params, "recommendation_reason") do

      attrs = attrs
      |> Map.put("place_id", place_id)
      |> Map.put("nearby_place_name", nearby_place_name)
      |> Map.put("recommendation_reason", recommendation_reason)

      # Optional fields
      attrs = maybe_add_optional_field(attrs, params, "description")
      attrs = maybe_add_optional_field(attrs, params, "recommendation_category")
      attrs = maybe_add_optional_field(attrs, params, "place_type")
      attrs = maybe_add_optional_field(attrs, params, "country_code")
      attrs = maybe_add_optional_field(attrs, params, "state_province")
      attrs = maybe_add_optional_field(attrs, params, "transportation_method")
      attrs = maybe_add_optional_field(attrs, params, "best_season")
      attrs = maybe_add_optional_field(attrs, params, "difficulty_level")
      attrs = maybe_add_optional_field(attrs, params, "estimated_visit_duration")
      attrs = maybe_add_optional_field(attrs, params, "google_place_id")
      attrs = maybe_add_optional_field(attrs, params, "location_iq_place_id")
      attrs = maybe_add_optional_field(attrs, params, "wikipedia_url")
      attrs = maybe_add_optional_field(attrs, params, "official_website")
      attrs = maybe_add_optional_field(attrs, params, "image_url")
      attrs = maybe_add_optional_field(attrs, params, "image_attribution")
      attrs = maybe_add_optional_field(attrs, params, "source")

      # Numeric fields
      attrs = maybe_add_numeric_field(attrs, params, "latitude")
      attrs = maybe_add_numeric_field(attrs, params, "longitude")
      attrs = maybe_add_numeric_field(attrs, params, "distance_km")
      attrs = maybe_add_numeric_field(attrs, params, "travel_time_minutes")
      attrs = maybe_add_numeric_field(attrs, params, "popularity_score")
      attrs = maybe_add_numeric_field(attrs, params, "sort_order")

      # Boolean fields
      attrs = maybe_add_boolean_field(attrs, params, "is_active")
      attrs = maybe_add_boolean_field(attrs, params, "verified")

      # Array fields
      attrs = maybe_add_array_field(attrs, params, "tips")

      {:ok, attrs}
    end
  end

  defp validate_update_params(params) do
    attrs = %{}

    # All fields are optional for updates
    attrs = maybe_add_optional_field(attrs, params, "nearby_place_name")
    attrs = maybe_add_optional_field(attrs, params, "recommendation_reason")
    attrs = maybe_add_optional_field(attrs, params, "description")
    attrs = maybe_add_optional_field(attrs, params, "recommendation_category")
    attrs = maybe_add_optional_field(attrs, params, "place_type")
    attrs = maybe_add_optional_field(attrs, params, "country_code")
    attrs = maybe_add_optional_field(attrs, params, "state_province")
    attrs = maybe_add_optional_field(attrs, params, "transportation_method")
    attrs = maybe_add_optional_field(attrs, params, "best_season")
    attrs = maybe_add_optional_field(attrs, params, "difficulty_level")
    attrs = maybe_add_optional_field(attrs, params, "estimated_visit_duration")
    attrs = maybe_add_optional_field(attrs, params, "google_place_id")
    attrs = maybe_add_optional_field(attrs, params, "location_iq_place_id")
    attrs = maybe_add_optional_field(attrs, params, "wikipedia_url")
    attrs = maybe_add_optional_field(attrs, params, "official_website")
    attrs = maybe_add_optional_field(attrs, params, "image_url")
    attrs = maybe_add_optional_field(attrs, params, "image_attribution")
    attrs = maybe_add_optional_field(attrs, params, "source")

    # Numeric fields
    attrs = maybe_add_numeric_field(attrs, params, "latitude")
    attrs = maybe_add_numeric_field(attrs, params, "longitude")
    attrs = maybe_add_numeric_field(attrs, params, "distance_km")
    attrs = maybe_add_numeric_field(attrs, params, "travel_time_minutes")
    attrs = maybe_add_numeric_field(attrs, params, "popularity_score")
    attrs = maybe_add_numeric_field(attrs, params, "sort_order")

    # Boolean fields
    attrs = maybe_add_boolean_field(attrs, params, "is_active")
    attrs = maybe_add_boolean_field(attrs, params, "verified")

    # Array fields
    attrs = maybe_add_array_field(attrs, params, "tips")

    {:ok, attrs}
  end

  defp validate_required_integer(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_val, ""} when int_val > 0 ->
            {:ok, int_val}
          _ ->
            {:error, {:bad_request, "#{key} must be a valid positive integer"}}
        end
      value when is_integer(value) and value > 0 ->
        {:ok, value}
      _ ->
        {:error, {:bad_request, "#{key} is required and must be a positive integer"}}
    end
  end

  defp maybe_add_optional_field(attrs, params, key) do
    case Map.get(params, key) do
      value when is_binary(value) and byte_size(value) > 0 ->
        Map.put(attrs, key, value)
      _ ->
        attrs
    end
  end

  defp maybe_add_numeric_field(attrs, params, key) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case Float.parse(value) do
          {float_val, ""} ->
            Map.put(attrs, key, float_val)
          _ ->
            attrs
        end
      value when is_number(value) ->
        Map.put(attrs, key, value)
      _ ->
        attrs
    end
  end

  defp maybe_add_boolean_field(attrs, params, key) do
    case Map.get(params, key) do
      true -> Map.put(attrs, key, true)
      false -> Map.put(attrs, key, false)
      "true" -> Map.put(attrs, key, true)
      "false" -> Map.put(attrs, key, false)
      _ -> attrs
    end
  end

  defp maybe_add_array_field(attrs, params, key) do
    case Map.get(params, key) do
      value when is_list(value) ->
        Map.put(attrs, key, value)
      _ ->
        attrs
    end
  end
end