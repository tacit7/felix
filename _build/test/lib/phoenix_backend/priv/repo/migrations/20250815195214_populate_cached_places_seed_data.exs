defmodule RouteWiseApi.Repo.Migrations.PopulateCachedPlacesSeedData do
  use Ecto.Migration
  import Ecto.Query
  
  alias RouteWiseApi.Repo

  def up do
    # Popular countries (place_type: 1)
    countries = [
      %{name: "United States", place_type: 1, country_code: "US", lat: 39.8283, lon: -98.5795, popularity_score: 100},
      %{name: "Canada", place_type: 1, country_code: "CA", lat: 56.1304, lon: -106.3468, popularity_score: 85},
      %{name: "United Kingdom", place_type: 1, country_code: "GB", lat: 55.3781, lon: -3.4360, popularity_score: 90},
      %{name: "Germany", place_type: 1, country_code: "DE", lat: 51.1657, lon: 10.4515, popularity_score: 88},
      %{name: "France", place_type: 1, country_code: "FR", lat: 46.2276, lon: 2.2137, popularity_score: 92},
      %{name: "Italy", place_type: 1, country_code: "IT", lat: 41.8719, lon: 12.5674, popularity_score: 87},
      %{name: "Spain", place_type: 1, country_code: "ES", lat: 40.4637, lon: -3.7492, popularity_score: 85},
      %{name: "Australia", place_type: 1, country_code: "AU", lat: -25.2744, lon: 133.7751, popularity_score: 82},
      %{name: "Japan", place_type: 1, country_code: "JP", lat: 36.2048, lon: 138.2529, popularity_score: 88},
      %{name: "Mexico", place_type: 1, country_code: "MX", lat: 23.6345, lon: -102.5528, popularity_score: 75}
    ]

    # Major cities (place_type: 3)
    cities = [
      # USA
      %{name: "New York", place_type: 3, country_code: "US", admin1_code: "US-NY", lat: 40.7128, lon: -74.0060, popularity_score: 95},
      %{name: "Los Angeles", place_type: 3, country_code: "US", admin1_code: "US-CA", lat: 34.0522, lon: -118.2437, popularity_score: 90},
      %{name: "Chicago", place_type: 3, country_code: "US", admin1_code: "US-IL", lat: 41.8781, lon: -87.6298, popularity_score: 85},
      %{name: "San Francisco", place_type: 3, country_code: "US", admin1_code: "US-CA", lat: 37.7749, lon: -122.4194, popularity_score: 88},
      %{name: "Miami", place_type: 3, country_code: "US", admin1_code: "US-FL", lat: 25.7617, lon: -80.1918, popularity_score: 80},
      %{name: "Las Vegas", place_type: 3, country_code: "US", admin1_code: "US-NV", lat: 36.1699, lon: -115.1398, popularity_score: 82},
      %{name: "Boston", place_type: 3, country_code: "US", admin1_code: "US-MA", lat: 42.3601, lon: -71.0589, popularity_score: 78},
      %{name: "Seattle", place_type: 3, country_code: "US", admin1_code: "US-WA", lat: 47.6062, lon: -122.3321, popularity_score: 85},
      
      # International
      %{name: "London", place_type: 3, country_code: "GB", lat: 51.5074, lon: -0.1278, popularity_score: 95},
      %{name: "Paris", place_type: 3, country_code: "FR", lat: 48.8566, lon: 2.3522, popularity_score: 93},
      %{name: "Tokyo", place_type: 3, country_code: "JP", lat: 35.6762, lon: 139.6503, popularity_score: 90},
      %{name: "Berlin", place_type: 3, country_code: "DE", lat: 52.5200, lon: 13.4050, popularity_score: 82},
      %{name: "Rome", place_type: 3, country_code: "IT", lat: 41.9028, lon: 12.4964, popularity_score: 88},
      %{name: "Barcelona", place_type: 3, country_code: "ES", lat: 41.3851, lon: 2.1734, popularity_score: 85},
      %{name: "Amsterdam", place_type: 3, country_code: "NL", lat: 52.3676, lon: 4.9041, popularity_score: 80},
      %{name: "Sydney", place_type: 3, country_code: "AU", lat: -33.8688, lon: 151.2093, popularity_score: 85},
      %{name: "Toronto", place_type: 3, country_code: "CA", lat: 43.6532, lon: -79.3832, popularity_score: 78},
      %{name: "Vancouver", place_type: 3, country_code: "CA", lat: 49.2827, lon: -123.1207, popularity_score: 75}
    ]

    # Famous POIs (place_type: 5)
    pois = [
      # USA Landmarks
      %{name: "Grand Canyon", place_type: 5, country_code: "US", admin1_code: "US-AZ", lat: 36.0544, lon: -112.1401, popularity_score: 95},
      %{name: "Yellowstone National Park", place_type: 5, country_code: "US", admin1_code: "US-WY", lat: 44.4280, lon: -110.5885, popularity_score: 90},
      %{name: "Times Square", place_type: 5, country_code: "US", admin1_code: "US-NY", lat: 40.7580, lon: -73.9855, popularity_score: 88},
      %{name: "Golden Gate Bridge", place_type: 5, country_code: "US", admin1_code: "US-CA", lat: 37.8199, lon: -122.4783, popularity_score: 90},
      %{name: "Statue of Liberty", place_type: 5, country_code: "US", admin1_code: "US-NY", lat: 40.6892, lon: -74.0445, popularity_score: 88},
      %{name: "Niagara Falls", place_type: 5, country_code: "US", admin1_code: "US-NY", lat: 43.0962, lon: -79.0377, popularity_score: 85},
      %{name: "Disney World", place_type: 5, country_code: "US", admin1_code: "US-FL", lat: 28.3772, lon: -81.5707, popularity_score: 90},
      %{name: "Mount Rushmore", place_type: 5, country_code: "US", admin1_code: "US-SD", lat: 43.8791, lon: -103.4591, popularity_score: 75},
      
      # International Landmarks
      %{name: "Eiffel Tower", place_type: 5, country_code: "FR", lat: 48.8584, lon: 2.2945, popularity_score: 95},
      %{name: "Big Ben", place_type: 5, country_code: "GB", lat: 51.5007, lon: -0.1246, popularity_score: 85},
      %{name: "Colosseum", place_type: 5, country_code: "IT", lat: 41.8902, lon: 12.4922, popularity_score: 92},
      %{name: "Sagrada Familia", place_type: 5, country_code: "ES", lat: 41.4036, lon: 2.1744, popularity_score: 88},
      %{name: "Sydney Opera House", place_type: 5, country_code: "AU", lat: -33.8568, lon: 151.2153, popularity_score: 90},
      %{name: "Tokyo Tower", place_type: 5, country_code: "JP", lat: 35.6586, lon: 139.7454, popularity_score: 82},
      %{name: "Brandenburg Gate", place_type: 5, country_code: "DE", lat: 52.5163, lon: 13.3777, popularity_score: 78},
      %{name: "CN Tower", place_type: 5, country_code: "CA", lat: 43.6426, lon: -79.3871, popularity_score: 75}
    ]

    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)
    
    # Insert all data with timestamps and IDs
    all_places = (countries ++ cities ++ pois)
    |> Enum.map(fn place ->
      Map.merge(place, %{
        id: Ecto.UUID.bingenerate(),
        inserted_at: timestamp,
        updated_at: timestamp,
        search_count: 0,
        source: "manual"
      })
    end)

    Repo.insert_all("cached_places", all_places)
    
    IO.puts("✅ Inserted #{length(all_places)} cached places for autocomplete")
  end

  def down do
    # Remove all manually seeded places
    Repo.delete_all(from(cp in "cached_places", where: cp.source == "manual"))
    IO.puts("🗑️ Removed all manually seeded cached places")
  end
end
