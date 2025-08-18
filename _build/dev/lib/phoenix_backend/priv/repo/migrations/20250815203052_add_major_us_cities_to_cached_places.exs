defmodule RouteWiseApi.Repo.Migrations.AddMajorUsCitiesToCachedPlaces do
  use Ecto.Migration
  import Ecto.Query
  
  alias RouteWiseApi.Repo

  def up do
    # Major missing US cities organized by region with accurate coordinates
    
    # Western US Cities
    western_cities = [
      %{name: "Denver", place_type: 3, country_code: "US", admin1_code: "US-CO", lat: 39.7392, lon: -104.9903, popularity_score: 78},
      %{name: "Portland", place_type: 3, country_code: "US", admin1_code: "US-OR", lat: 45.5152, lon: -122.6784, popularity_score: 75},
      %{name: "San Diego", place_type: 3, country_code: "US", admin1_code: "US-CA", lat: 32.7157, lon: -117.1611, popularity_score: 82},
      %{name: "Phoenix", place_type: 3, country_code: "US", admin1_code: "US-AZ", lat: 33.4484, lon: -112.0740, popularity_score: 75},
      %{name: "Salt Lake City", place_type: 3, country_code: "US", admin1_code: "US-UT", lat: 40.7608, lon: -111.8910, popularity_score: 70}
    ]

    # Southern US Cities
    southern_cities = [
      %{name: "Austin", place_type: 3, country_code: "US", admin1_code: "US-TX", lat: 30.2672, lon: -97.7431, popularity_score: 80},
      %{name: "Nashville", place_type: 3, country_code: "US", admin1_code: "US-TN", lat: 36.1627, lon: -86.7816, popularity_score: 78},
      %{name: "New Orleans", place_type: 3, country_code: "US", admin1_code: "US-LA", lat: 29.9511, lon: -90.0715, popularity_score: 85},
      %{name: "Atlanta", place_type: 3, country_code: "US", admin1_code: "US-GA", lat: 33.7490, lon: -84.3880, popularity_score: 78},
      %{name: "Charlotte", place_type: 3, country_code: "US", admin1_code: "US-NC", lat: 35.2271, lon: -80.8431, popularity_score: 70}
    ]

    # Eastern US Cities
    eastern_cities = [
      %{name: "Washington DC", place_type: 3, country_code: "US", admin1_code: "US-DC", lat: 38.9072, lon: -77.0369, popularity_score: 85},
      %{name: "Philadelphia", place_type: 3, country_code: "US", admin1_code: "US-PA", lat: 39.9526, lon: -75.1652, popularity_score: 80},
      %{name: "Pittsburgh", place_type: 3, country_code: "US", admin1_code: "US-PA", lat: 40.4406, lon: -79.9959, popularity_score: 70}
    ]

    # Special Destinations
    special_destinations = [
      %{name: "Honolulu", place_type: 3, country_code: "US", admin1_code: "US-HI", lat: 21.3099, lon: -157.8581, popularity_score: 88},
      %{name: "Anchorage", place_type: 3, country_code: "US", admin1_code: "US-AK", lat: 61.2181, lon: -149.9003, popularity_score: 70}
    ]

    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)
    
    # Combine all cities and add metadata
    all_cities = (western_cities ++ southern_cities ++ eastern_cities ++ special_destinations)
    |> Enum.map(fn city ->
      Map.merge(city, %{
        id: Ecto.UUID.bingenerate(),
        inserted_at: timestamp,
        updated_at: timestamp,
        search_count: 0,
        source: "manual"
      })
    end)

    # Insert cities
    Repo.insert_all("cached_places", all_cities)
    
    IO.puts("✅ Added #{length(all_cities)} major US cities to cached places:")
    IO.puts("   - #{length(western_cities)} Western cities")
    IO.puts("   - #{length(southern_cities)} Southern cities") 
    IO.puts("   - #{length(eastern_cities)} Eastern cities")
    IO.puts("   - #{length(special_destinations)} Special destinations (HI, AK)")
    IO.puts("📊 Total cached places: #{Repo.aggregate("cached_places", :count, :id)}")
  end

  def down do
    # Remove the added US cities by name
    city_names = [
      "Denver", "Portland", "San Diego", "Phoenix", "Salt Lake City",
      "Austin", "Nashville", "New Orleans", "Atlanta", "Charlotte", 
      "Washington DC", "Philadelphia", "Pittsburgh",
      "Honolulu", "Anchorage"
    ]
    
    {deleted_count, _} = Repo.delete_all(
      from(cp in "cached_places", 
        where: cp.name in ^city_names and cp.source == "manual" and cp.place_type == 3)
    )
    
    IO.puts("🗑️ Removed #{deleted_count} major US cities from cached places")
  end
end