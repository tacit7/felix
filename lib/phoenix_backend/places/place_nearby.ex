defmodule RouteWiseApi.Places.PlaceNearby do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "places_nearby" do
    # Relationship to main place
    belongs_to :place, RouteWiseApi.Places.Place

    # Core nearby place information
    field :nearby_place_name, :string
    field :recommendation_reason, :string
    field :description, :string

    # Geographic information
    field :latitude, :decimal
    field :longitude, :decimal
    field :distance_km, :decimal
    field :travel_time_minutes, :integer
    field :transportation_method, :string

    # Place details
    field :place_type, :string
    field :country_code, :string
    field :state_province, :string
    field :popularity_score, :integer

    # Recommendation metadata
    field :recommendation_category, :string
    field :best_season, :string
    field :difficulty_level, :string
    field :estimated_visit_duration, :string

    # External references (optional)
    field :google_place_id, :string
    field :location_iq_place_id, :string
    field :wikipedia_url, :string
    field :official_website, :string

    # Content and media
    field :tips, {:array, :string}
    field :image_url, :string
    field :image_attribution, :string

    # Metadata
    field :is_active, :boolean
    field :sort_order, :integer
    field :source, :string
    field :verified, :boolean
    field :last_verified_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  A place_nearby changeset for creation and updates.
  """
  def changeset(place_nearby, attrs) do
    place_nearby
    |> cast(attrs, [
      :place_id, :nearby_place_name, :recommendation_reason, :description,
      :latitude, :longitude, :distance_km, :travel_time_minutes,
      :transportation_method, :place_type, :country_code, :state_province,
      :popularity_score, :recommendation_category, :best_season,
      :difficulty_level, :estimated_visit_duration, :google_place_id,
      :location_iq_place_id, :wikipedia_url, :official_website, :tips,
      :image_url, :image_attribution, :is_active, :sort_order, :source,
      :verified, :last_verified_at
    ])
    |> validate_required([:place_id, :nearby_place_name, :recommendation_reason])
    |> validate_geographic_data()
    |> validate_enum_fields()
    |> validate_url_fields()
    |> validate_distances_and_times()
    |> foreign_key_constraint(:place_id)
    |> unique_constraint([:place_id, :nearby_place_name],
         name: :places_nearby_place_id_nearby_place_name_index)
  end

  @doc """
  Creates a changeset for admin/manual creation with additional validations.
  """
  def admin_changeset(place_nearby, attrs) do
    place_nearby
    |> changeset(attrs)
    |> validate_required([:recommendation_category, :place_type])
    |> put_change(:source, "manual")
    |> put_change(:verified, true)
    |> put_change(:last_verified_at, DateTime.utc_now())
  end

  @valid_transportation_methods ~w[driving walking public_transport flight ferry cycling]
  @valid_place_types ~w[city town attraction landmark neighborhood region park beach mountain]
  @valid_recommendation_categories ~w[day_trip base_city hidden_gem cultural_site adventure nature urban historical]
  @valid_seasons ~w[spring summer fall winter year_round]
  @valid_difficulty_levels ~w[easy moderate challenging]

  defp validate_geographic_data(changeset) do
    changeset
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_coordinates_consistency()
  end

  defp validate_enum_fields(changeset) do
    changeset
    |> validate_inclusion(:transportation_method, @valid_transportation_methods)
    |> validate_inclusion(:place_type, @valid_place_types)
    |> validate_inclusion(:recommendation_category, @valid_recommendation_categories)
    |> validate_inclusion(:best_season, @valid_seasons)
    |> validate_inclusion(:difficulty_level, @valid_difficulty_levels)
  end

  defp validate_url_fields(changeset) do
    changeset
    |> validate_url(:wikipedia_url)
    |> validate_url(:official_website)
    |> validate_url(:image_url)
  end

  defp validate_distances_and_times(changeset) do
    changeset
    |> validate_number(:distance_km, greater_than: 0)
    |> validate_number(:travel_time_minutes, greater_than: 0)
    |> validate_number(:popularity_score, greater_than_or_equal_to: 0)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
  end

  defp validate_coordinates_consistency(changeset) do
    lat = get_field(changeset, :latitude)
    lng = get_field(changeset, :longitude)

    case {lat, lng} do
      {nil, nil} -> changeset
      {lat, lng} when not is_nil(lat) and not is_nil(lng) -> changeset
      _ ->
        add_error(changeset, :base, "both latitude and longitude must be provided together")
    end
  end

  defp validate_url(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      url when is_binary(url) ->
        if String.match?(url, ~r/^https?:\/\//), do: changeset, else: add_error(changeset, field, "must be a valid URL")
      _ -> add_error(changeset, field, "must be a string")
    end
  end

  @doc """
  Calculates approximate distance between two geographic points using Haversine formula.
  Returns distance in kilometers.
  """
  def calculate_distance(lat1, lng1, lat2, lng2) when not is_nil(lat1) and not is_nil(lng1) and not is_nil(lat2) and not is_nil(lng2) do
    # Convert to floats for calculation
    lat1 = lat1 |> Decimal.to_float()
    lng1 = lng1 |> Decimal.to_float()
    lat2 = lat2 |> Decimal.to_float()
    lng2 = lng2 |> Decimal.to_float()

    # Haversine formula
    dlat = :math.pi() * (lat2 - lat1) / 180
    dlng = :math.pi() * (lng2 - lng1) / 180

    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(:math.pi() * lat1 / 180) * :math.cos(:math.pi() * lat2 / 180) *
        :math.sin(dlng / 2) * :math.sin(dlng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    distance = 6371 * c # Radius of earth in km

    Decimal.from_float(distance) |> Decimal.round(2)
  end
  def calculate_distance(_, _, _, _), do: nil

  @doc """
  Returns a filtered list of nearby places based on criteria.
  """
  def filter_by_criteria(query, opts \\ []) do
    import Ecto.Query

    query
    |> filter_by_active(opts[:active])
    |> filter_by_category(opts[:category])
    |> filter_by_place_type(opts[:place_type])
    |> filter_by_max_distance(opts[:max_distance_km])
    |> filter_by_season(opts[:season])
    |> order_by_preference(opts[:order_by])
  end

  defp filter_by_active(query, nil) do
    import Ecto.Query
    where(query, [p], p.is_active == true)
  end
  defp filter_by_active(query, active) do
    import Ecto.Query
    where(query, [p], p.is_active == ^active)
  end

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, category) do
    import Ecto.Query
    where(query, [p], p.recommendation_category == ^category)
  end

  defp filter_by_place_type(query, nil), do: query
  defp filter_by_place_type(query, place_type) do
    import Ecto.Query
    where(query, [p], p.place_type == ^place_type)
  end

  defp filter_by_max_distance(query, nil), do: query
  defp filter_by_max_distance(query, max_distance) do
    import Ecto.Query
    where(query, [p], p.distance_km <= ^max_distance or is_nil(p.distance_km))
  end

  defp filter_by_season(query, nil), do: query
  defp filter_by_season(query, season) do
    import Ecto.Query
    where(query, [p], p.best_season == ^season or p.best_season == "year_round")
  end

  defp order_by_preference(query, nil) do
    import Ecto.Query
    order_by(query, [p], [asc: p.sort_order, desc: p.popularity_score])
  end
  defp order_by_preference(query, "distance") do
    import Ecto.Query
    order_by(query, [p], [asc: p.distance_km])
  end
  defp order_by_preference(query, "popularity") do
    import Ecto.Query
    order_by(query, [p], [desc: p.popularity_score])
  end
  defp order_by_preference(query, "name") do
    import Ecto.Query
    order_by(query, [p], [asc: p.nearby_place_name])
  end
  defp order_by_preference(query, _) do
    import Ecto.Query
    order_by(query, [p], [asc: p.sort_order, desc: p.popularity_score])
  end

  @doc """
  Returns valid enum values for frontend forms.
  """
  def valid_transportation_methods, do: @valid_transportation_methods
  def valid_place_types, do: @valid_place_types
  def valid_recommendation_categories, do: @valid_recommendation_categories
  def valid_seasons, do: @valid_seasons
  def valid_difficulty_levels, do: @valid_difficulty_levels
end