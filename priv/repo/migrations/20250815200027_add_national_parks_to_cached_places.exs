defmodule RouteWiseApi.Repo.Migrations.AddNationalParksToCachedPlaces do
  use Ecto.Migration
  import Ecto.Query
  
  alias RouteWiseApi.Repo

  def up do
    # Tier 1 - Most Popular National Parks (8 parks)
    tier1_parks = [
      %{name: "Yosemite National Park", place_type: 5, country_code: "US", admin1_code: "US-CA", 
        lat: 37.8651, lon: -119.5383, popularity_score: 95},
      %{name: "Great Smoky Mountains National Park", place_type: 5, country_code: "US", admin1_code: "US-TN", 
        lat: 35.6118, lon: -83.4895, popularity_score: 94},
      %{name: "Zion National Park", place_type: 5, country_code: "US", admin1_code: "US-UT", 
        lat: 37.2982, lon: -113.0263, popularity_score: 93},
      %{name: "Rocky Mountain National Park", place_type: 5, country_code: "US", admin1_code: "US-CO", 
        lat: 40.3428, lon: -105.6836, popularity_score: 92},
      %{name: "Acadia National Park", place_type: 5, country_code: "US", admin1_code: "US-ME", 
        lat: 44.3386, lon: -68.2733, popularity_score: 91},
      %{name: "Olympic National Park", place_type: 5, country_code: "US", admin1_code: "US-WA", 
        lat: 47.8021, lon: -123.6044, popularity_score: 90},
      %{name: "Glacier National Park", place_type: 5, country_code: "US", admin1_code: "US-MT", 
        lat: 48.7596, lon: -113.7870, popularity_score: 89},
      %{name: "Arches National Park", place_type: 5, country_code: "US", admin1_code: "US-UT", 
        lat: 38.7331, lon: -109.5925, popularity_score: 88}
    ]

    # Tier 2 - Popular Western Parks (5 parks)
    tier2_parks = [
      %{name: "Joshua Tree National Park", place_type: 5, country_code: "US", admin1_code: "US-CA", 
        lat: 33.8734, lon: -115.9010, popularity_score: 87},
      %{name: "Bryce Canyon National Park", place_type: 5, country_code: "US", admin1_code: "US-UT", 
        lat: 37.5930, lon: -112.1871, popularity_score: 86},
      %{name: "Death Valley National Park", place_type: 5, country_code: "US", admin1_code: "US-CA", 
        lat: 36.5054, lon: -117.0794, popularity_score: 85},
      %{name: "Sequoia National Park", place_type: 5, country_code: "US", admin1_code: "US-CA", 
        lat: 36.4864, lon: -118.5658, popularity_score: 84},
      %{name: "Crater Lake National Park", place_type: 5, country_code: "US", admin1_code: "US-OR", 
        lat: 42.8684, lon: -122.1685, popularity_score: 83}
    ]

    # Tier 3 - Other Notable Parks (5 parks)
    tier3_parks = [
      %{name: "Everglades National Park", place_type: 5, country_code: "US", admin1_code: "US-FL", 
        lat: 25.2866, lon: -80.8987, popularity_score: 82},
      %{name: "Grand Teton National Park", place_type: 5, country_code: "US", admin1_code: "US-WY", 
        lat: 43.7904, lon: -110.6818, popularity_score: 81},
      %{name: "Capitol Reef National Park", place_type: 5, country_code: "US", admin1_code: "US-UT", 
        lat: 38.2872, lon: -111.2479, popularity_score: 80},
      %{name: "Canyonlands National Park", place_type: 5, country_code: "US", admin1_code: "US-UT", 
        lat: 38.3269, lon: -109.8783, popularity_score: 79},
      %{name: "Big Bend National Park", place_type: 5, country_code: "US", admin1_code: "US-TX", 
        lat: 29.1275, lon: -103.2425, popularity_score: 78}
    ]

    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)
    
    # Combine all parks and add metadata
    all_parks = (tier1_parks ++ tier2_parks ++ tier3_parks)
    |> Enum.map(fn park ->
      Map.merge(park, %{
        id: Ecto.UUID.bingenerate(),
        inserted_at: timestamp,
        updated_at: timestamp,
        search_count: 0,
        source: "manual"
      })
    end)

    # Insert national parks
    Repo.insert_all("cached_places", all_parks)
    
    IO.puts("✅ Added #{length(all_parks)} US National Parks to cached places:")
    IO.puts("   - #{length(tier1_parks)} Tier 1 parks (popularity: 88-95)")
    IO.puts("   - #{length(tier2_parks)} Tier 2 parks (popularity: 83-87)")
    IO.puts("   - #{length(tier3_parks)} Tier 3 parks (popularity: 78-82)")
    IO.puts("📊 Total cached places: #{Repo.aggregate("cached_places", :count, :id)}")
  end

  def down do
    # Remove national parks by name pattern
    national_park_names = [
      "Yosemite National Park", "Great Smoky Mountains National Park", "Zion National Park",
      "Rocky Mountain National Park", "Acadia National Park", "Olympic National Park",
      "Glacier National Park", "Arches National Park", "Joshua Tree National Park", 
      "Bryce Canyon National Park", "Death Valley National Park", "Sequoia National Park",
      "Crater Lake National Park", "Everglades National Park", "Grand Teton National Park",
      "Capitol Reef National Park", "Canyonlands National Park", "Big Bend National Park"
    ]
    
    {deleted_count, _} = Repo.delete_all(
      from(cp in "cached_places", 
        where: cp.name in ^national_park_names and cp.source == "manual")
    )
    
    IO.puts("🗑️ Removed #{deleted_count} National Parks from cached places")
  end
end
