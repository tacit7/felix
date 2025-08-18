defmodule RouteWiseApi.Places.CachedPlace do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cached_places" do
    field :name, :string
    field :place_type, :integer
    field :country_code, :string
    field :admin1_code, :string
    field :lat, :float
    field :lon, :float
    field :popularity_score, :integer, default: 0
    field :search_count, :integer, default: 0
    field :source, :string, default: "manual"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Place types for cached places:
  - 1: Country
  - 3: City/Town
  - 5: POI/Landmark
  """
  def place_types do
    %{
      country: 1,
      city: 3,
      poi: 5
    }
  end

  @doc false
  def changeset(cached_place, attrs) do
    cached_place
    |> cast(attrs, [:name, :place_type, :country_code, :admin1_code, :lat, :lon, :popularity_score, :search_count, :source])
    |> validate_required([:name, :place_type])
    |> validate_inclusion(:place_type, [1, 3, 5])
    |> validate_length(:country_code, is: 2)
    |> validate_inclusion(:source, ["manual", "locationiq", "google"])
    |> validate_number(:lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:lon, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:popularity_score, greater_than_or_equal_to: 0)
    |> validate_number(:search_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Create changeset for incrementing search count
  """
  def increment_search_changeset(cached_place) do
    cached_place
    |> cast(%{search_count: cached_place.search_count + 1}, [:search_count])
  end
end