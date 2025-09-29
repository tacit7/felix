defmodule RouteWiseApi.Places.Place do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "pois" do
    field :google_place_id, :string
    field :location_iq_place_id, :string
    field :name, :string
    field :formatted_address, :string
    field :latitude, :decimal
    field :longitude, :decimal
    field :categories, {:array, :string}
    field :rating, :decimal
    field :price_level, :integer
    field :phone_number, :string
    field :website, :string
    field :opening_hours, :map
    field :photos, {:array, :map}
    field :reviews_count, :integer
    field :google_data, :map
    field :location_iq_data, :map
    field :cached_at, :utc_datetime
    field :location, Geo.PostGIS.Geometry  # PostGIS point for geospatial queries
    
    # Search fields
    field :description, :string
    field :search_vector, :map, virtual: true  # PostgreSQL tsvector, handled by triggers
    field :popularity_score, :integer
    field :last_updated, :utc_datetime
    field :wiki_image, :string
    field :tripadvisor_url, :string
    field :tips, {:array, :string}
    
    # Hidden gem classification
    field :hidden_gem, :boolean
    field :hidden_gem_reason, :string
    
    # Overrated classification
    field :overrated, :boolean
    field :overrated_reason, :string
    
    # TripAdvisor specific data
    field :tripadvisor_rating, :decimal
    field :tripadvisor_review_count, :integer
    
    # Practical visit information
    field :entry_fee, :string
    field :best_time_to_visit, :string
    field :accessibility, :string
    field :duration_suggested, :string
    
    # Relationships and metadata
    field :related_places, {:array, :string}
    field :local_name, :string
    field :wikidata_id, :string
    
    # Editorial curation flag
    field :curated, :boolean, default: false
    
    # Google image caching fields
    field :image_data, :map
    field :cached_image_original, :string
    field :cached_image_thumb, :string
    field :cached_image_medium, :string
    field :cached_image_large, :string
    field :cached_image_xlarge, :string
    field :images_cached_at, :utc_datetime
    field :image_processing_status, :string
    field :image_processing_error, :string

    # Default placeholder image association
    belongs_to :default_image, RouteWiseApi.Places.DefaultImage

    # Nearby places recommendations
    has_many :nearby_places, RouteWiseApi.Places.PlaceNearby, foreign_key: :place_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  A place changeset for creation from API data (Google Places or LocationIQ).
  """
  def changeset(place, attrs) do
    place
    |> cast(attrs, [
      :google_place_id, :location_iq_place_id, :name, :formatted_address,
      :latitude, :longitude, :categories, :rating, :price_level, :phone_number,
      :website, :opening_hours, :photos, :reviews_count, :google_data,
      :location_iq_data, :cached_at, :wiki_image, :tripadvisor_url, :tips,
      :hidden_gem, :hidden_gem_reason, :overrated, :overrated_reason,
      :tripadvisor_rating, :tripadvisor_review_count, :entry_fee, :best_time_to_visit,
      :accessibility, :duration_suggested, :related_places, :local_name, :wikidata_id,
      :curated, :image_data, :cached_image_original, :cached_image_thumb,
      :cached_image_medium, :cached_image_large, :cached_image_xlarge,
      :images_cached_at, :image_processing_status, :image_processing_error,
      :default_image_id
    ])
    |> validate_required([:name, :cached_at])
    |> validate_one_place_id()
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:rating, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:price_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> unique_constraint(:google_place_id)
    |> unique_constraint(:location_iq_place_id)
  end

  @doc """
  A place changeset for manual imports with description field.
  """
  def manual_changeset(place, attrs) do
    # Automatically mark manual imports as curated
    attrs = Map.put(attrs, :curated, true)
    
    place
    |> cast(attrs, [
      :google_place_id, :location_iq_place_id, :name, :formatted_address,
      :latitude, :longitude, :categories, :rating, :price_level, :phone_number,
      :website, :opening_hours, :photos, :reviews_count, :google_data,
      :location_iq_data, :cached_at, :description, :wiki_image, :tripadvisor_url, :tips,
      :hidden_gem, :hidden_gem_reason, :overrated, :overrated_reason,
      :tripadvisor_rating, :tripadvisor_review_count, :entry_fee, :best_time_to_visit,
      :accessibility, :duration_suggested, :related_places, :local_name, :wikidata_id,
      :curated, :image_data, :cached_image_original, :cached_image_thumb,
      :cached_image_medium, :cached_image_large, :cached_image_xlarge,
      :images_cached_at, :image_processing_status, :image_processing_error,
      :default_image_id
    ])
    |> validate_required([:name, :cached_at])
    |> validate_one_place_id()
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:rating, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:price_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> unique_constraint(:google_place_id)
    |> unique_constraint(:location_iq_place_id)
  end

  defp validate_one_place_id(changeset) do
    google_id = get_field(changeset, :google_place_id)
    location_iq_id = get_field(changeset, :location_iq_place_id)

    case {google_id, location_iq_id} do
      {nil, nil} ->
        add_error(changeset, :base, "must have either google_place_id or location_iq_place_id")
      _ ->
        changeset
    end
  end

  @doc """
  Creates a Place struct from Google Places API response data.
  """
  def from_google_response(google_data) do
    %{
      google_place_id: google_data["place_id"],
      name: google_data["name"],
      formatted_address: google_data["formatted_address"],
      latitude: get_in(google_data, ["geometry", "location", "lat"]),
      longitude: get_in(google_data, ["geometry", "location", "lng"]),
      categories: google_data["types"] || [],
      rating: google_data["rating"],
      price_level: google_data["price_level"],
      phone_number: google_data["formatted_phone_number"],
      website: google_data["website"],
      opening_hours: parse_opening_hours(google_data["opening_hours"]),
      photos: parse_photos(google_data["photos"]),
      reviews_count: length(google_data["reviews"] || []),
      google_data: google_data,
      cached_at: DateTime.utc_now()
    }
  end

  @doc """
  Creates a Place struct from LocationIQ API response data.
  """
  def from_location_iq_response(location_iq_data) do
    %{
      location_iq_place_id: to_string(location_iq_data[:place_id] || location_iq_data["place_id"]),
      name: location_iq_data[:name] || location_iq_data["name"],
      formatted_address: location_iq_data[:address] || location_iq_data["address"],
      latitude: parse_coordinate(location_iq_data[:lat] || location_iq_data["lat"]),
      longitude: parse_coordinate(location_iq_data[:lng] || location_iq_data["lng"]),
      categories: [location_iq_data[:category] || location_iq_data["category"] || "place"],
      rating: nil, # LocationIQ doesn't provide ratings like Google
      price_level: nil, # LocationIQ doesn't provide price levels
      phone_number: nil, # Would need separate API call
      website: nil, # Would need separate API call
      opening_hours: nil, # Would need separate API call  
      photos: [], # LocationIQ doesn't provide photos like Google
      reviews_count: 0, # LocationIQ doesn't provide review counts
      location_iq_data: location_iq_data,
      cached_at: DateTime.utc_now()
    }
  end

  defp parse_coordinate(coord) when is_binary(coord) do
    try do
      Decimal.new(coord)
    rescue
      _ -> nil
    end
  end
  defp parse_coordinate(coord) when is_number(coord), do: Decimal.new(to_string(coord))
  defp parse_coordinate(_), do: nil

  @doc """
  Checks if cached place data is still fresh (within cache TTL).
  """
  def cache_fresh?(%__MODULE__{cached_at: cached_at}, ttl_hours \\ 24) do
    cache_expiry = DateTime.add(cached_at, ttl_hours * 3600, :second)
    DateTime.compare(DateTime.utc_now(), cache_expiry) == :lt
  end

  defp parse_opening_hours(nil), do: nil
  defp parse_opening_hours(opening_hours) do
    %{
      open_now: opening_hours["open_now"],
      weekday_text: opening_hours["weekday_text"] || [],
      periods: opening_hours["periods"] || []
    }
  end

  defp parse_photos(nil), do: []
  defp parse_photos(photos) when is_list(photos) do
    Enum.map(photos, fn photo ->
      %{
        photo_reference: photo["photo_reference"],
        width: photo["width"],
        height: photo["height"],
        html_attributions: photo["html_attributions"] || []
      }
    end)
  end
  defp parse_photos(_), do: []
end