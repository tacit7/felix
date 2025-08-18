defmodule RouteWiseApi.Trips.InterestCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias RouteWiseApi.Trips.UserInterest

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "interest_categories" do
    field :name, :string
    field :display_name, :string
    field :description, :string
    field :icon_name, :string
    field :is_active, :boolean, default: true

    has_many :user_interests, UserInterest, foreign_key: :category_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  An interest category changeset for creation and updates.
  """
  def changeset(interest_category, attrs) do
    interest_category
    |> cast(attrs, [:name, :display_name, :description, :icon_name, :is_active])
    |> validate_required([:name, :display_name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:display_name, min: 1, max: 255)
    |> validate_format(:name, ~r/^[a-z_]+$/, 
         message: "must contain only lowercase letters and underscores")
    |> unique_constraint(:name)
  end

  @doc """
  Returns the default interest categories.
  """
  def default_categories do
    [
      %{
        name: "restaurants",
        display_name: "Restaurants",
        description: "Dining establishments and food experiences",
        icon_name: "restaurant",
        is_active: true
      },
      %{
        name: "attractions",
        display_name: "Tourist Attractions",
        description: "Popular tourist destinations and landmarks",
        icon_name: "attraction",
        is_active: true
      },
      %{
        name: "parks",
        display_name: "Parks & Nature",
        description: "Parks, gardens, and natural areas",
        icon_name: "park",
        is_active: true
      },
      %{
        name: "museums",
        display_name: "Museums & Culture",
        description: "Museums, galleries, and cultural sites",
        icon_name: "museum",
        is_active: true
      },
      %{
        name: "shopping",
        display_name: "Shopping",
        description: "Shopping centers, markets, and stores",
        icon_name: "shopping",
        is_active: true
      },
      %{
        name: "entertainment",
        display_name: "Entertainment",
        description: "Entertainment venues and activities",
        icon_name: "entertainment",
        is_active: true
      },
      %{
        name: "nightlife",
        display_name: "Nightlife",
        description: "Bars, clubs, and nighttime activities",
        icon_name: "nightlife",
        is_active: true
      },
      %{
        name: "outdoor",
        display_name: "Outdoor Activities",
        description: "Hiking, sports, and outdoor recreation",
        icon_name: "outdoor",
        is_active: true
      }
    ]
  end
end