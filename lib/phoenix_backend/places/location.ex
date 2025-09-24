defmodule RouteWiseApi.Places.Location do
  @moduledoc """
  Schema for caching location data from LocationIQ API.

  This module stores geographic location information including cities, regions,
  countries, parks, and other place types with popularity tracking to reduce
  API calls and improve autocomplete performance.

  Locations are stored with structured columns for fast querying and include
  usage statistics to prioritize popular locations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @location_types ~w(city town village region state province country park national_park monument landmark)

  schema "locations" do
    field :location_iq_place_id, :string
    field :name, :string
    field :display_name, :string
    field :normalized_name, :string
    field :latitude, :decimal
    field :longitude, :decimal
    field :city_type, :string  # Original LocationIQ type (kept for compatibility)
    field :location_type, :string  # Normalized type (city, region, country, park, etc.)
    field :state, :string
    field :country, :string
    field :country_code, :string
    field :search_count, :integer, default: 0
    field :last_searched_at, :utc_datetime

    # Geographic bounds for accurate search radius calculation
    field :bbox_north, :decimal
    field :bbox_south, :decimal
    field :bbox_east, :decimal
    field :bbox_west, :decimal
    field :search_radius_meters, :integer
    field :bounds_source, :string
    field :bounds_updated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(location_iq_place_id name display_name latitude longitude country country_code location_type)a
  @optional_fields ~w(city_type state search_count last_searched_at normalized_name bbox_north bbox_south bbox_east bbox_west search_radius_meters bounds_source bounds_updated_at)a

  @doc """
  Creates a changeset for location validation and casting.

  Validates required fields, coordinate ranges, location types, and applies
  unique constraints for LocationIQ place IDs.

  ## Parameters
  - location: Location struct or changeset
  - attrs: Map of attributes to cast and validate

  ## Examples
      iex> changeset(%Location{}, %{name: "San Francisco", location_type: "city", latitude: 37.7749, ...})
      %Ecto.Changeset{valid?: true}

      iex> changeset(%Location{}, %{name: "", location_type: "invalid", latitude: 200})
      %Ecto.Changeset{valid?: false}
  """
  def changeset(location, attrs) do
    location
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:display_name, min: 1, max: 255)
    |> validate_length(:country_code, is: 2)
    |> validate_inclusion(:location_type, @location_types)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:search_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:location_iq_place_id)
  end

  @doc """
  Returns the list of valid location types.
  """
  def location_types, do: @location_types

  @doc """
  Determines location type based on city_type field from LocationIQ.

  ## Examples
      iex> infer_location_type("national park")
      "park"

      iex> infer_location_type("administrative")
      "region"
  """
  def infer_location_type(city_type) when is_binary(city_type) do
    city_type = String.downcase(city_type)

    cond do
      String.contains?(city_type, "park") -> "park"
      String.contains?(city_type, "monument") -> "monument"
      String.contains?(city_type, "landmark") -> "landmark"
      city_type in ["region", "administrative"] -> "region"
      city_type in ["state", "province"] -> "state"
      city_type == "country" -> "country"
      city_type in ["town", "village"] -> city_type
      true -> "city"
    end
  end

  def infer_location_type(_), do: "city"
end