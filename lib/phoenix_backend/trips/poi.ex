defmodule RouteWiseApi.Trips.POI do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "pois" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :rating, :decimal
    field :review_count, :integer
    field :time_from_start, :string
    field :image_url, :string
    field :place_id, :string
    field :address, :string
    field :price_level, :integer
    field :is_open, :boolean
    field :latitude, :float
    field :longitude, :float
    
    # Enriched POI fields
    field :tips, {:array, :string}, default: []
    field :best_time_to_visit, :string
    field :duration_suggested, :string
    field :accessibility, :string
    field :entry_fee, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  A POI changeset for creation and updates.
  """
  def changeset(poi, attrs) do
    poi
    |> cast(attrs, [
      :name, :description, :category, :rating, :review_count,
      :time_from_start, :image_url, :place_id, :address,
      :price_level, :is_open, :latitude, :longitude,
      :tips, :best_time_to_visit, :duration_suggested, 
      :accessibility, :entry_fee
    ])
    |> validate_required([:name, :description, :category, :rating, :review_count, :time_from_start, :image_url, :latitude, :longitude])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:category, min: 1, max: 100)
    |> validate_number(:rating, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:review_count, greater_than_or_equal_to: 0)
    |> validate_number(:price_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_format(:image_url, ~r/^https?:\/\//, message: "must be a valid URL")
  end

  @doc """
  Creates a POI from Google Places data.
  """
  def from_google_place(place_data, time_from_start \\ "0 hours") do
    %{
      name: place_data["name"],
      description: get_description(place_data),
      category: get_primary_category(place_data["types"]),
      rating: place_data["rating"] || 0.0,
      review_count: place_data["user_ratings_total"] || 0,
      time_from_start: time_from_start,
      image_url: get_photo_url(place_data["photos"]),
      place_id: place_data["place_id"],
      address: place_data["formatted_address"],
      price_level: place_data["price_level"],
      is_open: get_in(place_data, ["opening_hours", "open_now"]),
      latitude: get_in(place_data, ["geometry", "location", "lat"]),
      longitude: get_in(place_data, ["geometry", "location", "lng"])
    }
  end

  defp get_primary_category(types) when is_list(types) do
    # Map Google Place types to our POI categories
    category_mapping = %{
      "restaurant" => "restaurant",
      "food" => "restaurant", 
      "meal_takeaway" => "restaurant",
      "tourist_attraction" => "attraction",
      "point_of_interest" => "attraction",
      "park" => "park",
      "museum" => "museum",
      "art_gallery" => "museum",
      "shopping_mall" => "market",
      "store" => "market",
      "lodging" => "historic",
      "church" => "historic",
      "cemetery" => "historic"
    }
    
    primary_type = Enum.find(types, fn type -> 
      Map.has_key?(category_mapping, type) 
    end)
    
    category_mapping[primary_type] || "attraction"
  end
  defp get_primary_category(_), do: "attraction"

  defp get_description(place_data) do
    cond do
      # First try editorial summary
      place_data["editorial_summary"]["overview"] ->
        place_data["editorial_summary"]["overview"]
      
      # Then try business status and types
      place_data["business_status"] == "OPERATIONAL" and place_data["types"] ->
        types = place_data["types"] || []
        primary_type = get_readable_type(types)
        rating = place_data["rating"]
        review_count = place_data["user_ratings_total"]
        
        case {rating, review_count} do
          {nil, _} -> "#{primary_type}"
          {rating, nil} -> "#{primary_type} • #{rating}★"
          {rating, count} when count > 0 -> "#{primary_type} • #{rating}★ (#{count} reviews)"
          _ -> "#{primary_type}"
        end
      
      # Fallback to just the readable type
      place_data["types"] ->
        get_readable_type(place_data["types"])
      
      # Last resort
      true ->
        "Point of interest"
    end
  end

  defp get_readable_type(types) when is_list(types) do
    # Convert Google Place types to readable descriptions
    readable_mapping = %{
      "restaurant" => "Restaurant",
      "food" => "Restaurant",
      "meal_takeaway" => "Takeout Restaurant",
      "cafe" => "Cafe",
      "tourist_attraction" => "Tourist Attraction",
      "park" => "Park",
      "amusement_park" => "Amusement Park",
      "museum" => "Museum",
      "art_gallery" => "Art Gallery",
      "shopping_mall" => "Shopping Mall",
      "store" => "Store",
      "gas_station" => "Gas Station",
      "lodging" => "Hotel",
      "church" => "Church",
      "hospital" => "Hospital",
      "school" => "School",
      "bank" => "Bank",
      "pharmacy" => "Pharmacy",
      "gym" => "Gym",
      "beauty_salon" => "Beauty Salon",
      "night_club" => "Night Club",
      "bar" => "Bar",
      "movie_theater" => "Movie Theater"
    }
    
    # Find the first type that has a readable mapping
    readable_type = Enum.find_value(types, fn type ->
      readable_mapping[type]
    end)
    
    # If no specific mapping found, use the first type and make it readable
    readable_type || 
      types
      |> List.first()
      |> String.replace("_", " ")
      |> String.split(" ")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")
  end
  defp get_readable_type(_), do: "Point of Interest"

  defp get_photo_url(photos) when is_list(photos) and length(photos) > 0 do
    # Return a placeholder URL - in production, this would construct the actual Google Photos URL
    "https://via.placeholder.com/400x300?text=" <> URI.encode("Photo Available")
  end
  defp get_photo_url(_), do: "https://via.placeholder.com/400x300?text=" <> URI.encode("No Photo")

  @doc """
  Returns available POI categories.
  """
  def categories do
    ["restaurant", "park", "attraction", "scenic", "market", "historic"]
  end
end