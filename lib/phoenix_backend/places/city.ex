defmodule RouteWiseApi.Places.City do
  @moduledoc """
  Schema for caching city data from LocationIQ API.
  
  This module stores city information with popularity tracking
  to reduce API calls and improve autocomplete performance.
  
  Cities are stored with structured columns for fast querying
  and include usage statistics to prioritize popular locations.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cities" do
    field :location_iq_place_id, :string
    field :name, :string
    field :display_name, :string
    field :normalized_name, :string
    field :latitude, :decimal
    field :longitude, :decimal
    field :city_type, :string
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

  @required_fields ~w(location_iq_place_id name display_name latitude longitude country country_code)a
  @optional_fields ~w(city_type state search_count last_searched_at normalized_name bbox_north bbox_south bbox_east bbox_west search_radius_meters bounds_source bounds_updated_at)a

  @doc """
  Creates a changeset for city validation and casting.

  Validates required fields, coordinate ranges, and applies
  unique constraints for LocationIQ place IDs.

  ## Parameters
  - city: City struct or changeset
  - attrs: Map of attributes to cast and validate

  ## Examples
      iex> changeset(%City{}, %{name: "San Francisco", latitude: 37.7749, ...})
      %Ecto.Changeset{valid?: true}

      iex> changeset(%City{}, %{name: "", latitude: 200})
      %Ecto.Changeset{valid?: false}
  """
  def changeset(city, attrs) do
    city
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:display_name, min: 1, max: 255)
    |> validate_length(:country_code, is: 2)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:search_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:location_iq_place_id)
  end
end