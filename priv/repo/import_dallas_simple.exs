# Simple import script for Dallas places data
alias RouteWiseApi.{Repo, Places.Place}

# Dallas places data
places_data = [
  %{
    name: "The Sixth Floor Museum at Dealey Plaza",
    latitude: 32.779167,
    longitude: -96.808889,
    place_types: ["museum", "historical_site"],
    description: "Museum chronicling JFK's life, presidency, and assassination, located on the sixth and seventh floors of the former Texas School Book Depository building. Features exhibits detailing the history of the 1960s and the impact of JFK's legacy.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Sixth_Floor_Museum_at_Dealey_Plaza.jpg"
  },
  %{
    name: "Dealey Plaza",
    latitude: 32.778889,
    longitude: -96.808056,
    place_types: ["historical_site", "landmark"],
    description: "Historic birthplace of Dallas and site of President Kennedy's assassination. A National Historic Landmark that serves as a memorial to this pivotal moment in American history.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Dealey_Plaza_2003.jpg"
  },
  %{
    name: "Kennedy Memorial",
    latitude: 32.776389,
    longitude: -96.806944,
    place_types: ["memorial", "landmark"],
    description: "Memorial to President John F. Kennedy located near Dealey Plaza. A simple yet powerful tribute designed by architect Philip Johnson, featuring a square concrete structure.",
    wiki_image: "https://en.wikipedia.org/wiki/File:JFK_Memorial_Dallas.jpg"
  },
  %{
    name: "Pioneer Plaza",
    latitude: 32.776111,
    longitude: -96.807222,
    place_types: ["park", "sculpture", "landmark"],
    description: "Features the world's largest bronze sculpture of a cattle drive with 49 bronze steers and three cowboys. This impressive installation commemorates Dallas's cattle-driving heritage.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Pioneer_Plaza_Dallas.jpg"
  },
  %{
    name: "Dallas Museum of Art",
    latitude: 32.787778,
    longitude: -96.801111,
    place_types: ["museum", "art_gallery", "culture"],
    description: "Houses a collection spanning artistic eras and continents with free admission to permanent collections. Features contemporary and classical works, ancient artifacts, and rotating exhibitions.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Dallas_Museum_of_Art_building.jpg"
  },
  %{
    name: "Perot Museum of Nature and Science",
    latitude: 32.786944,
    longitude: -96.806667,
    place_types: ["museum", "family_attraction", "education"],
    description: "Top family attraction featuring interactive exhibits that engage children and adults in learning about natural history, space, technology, and science.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Perot_Museum_of_Nature_and_Science.jpg"
  },
  %{
    name: "Nasher Sculpture Center",
    latitude: 32.788333,
    longitude: -96.801389,
    place_types: ["museum", "art_gallery", "sculpture"],
    description: "Premier modern and contemporary sculpture collection housed in a stunning building designed by Renzo Piano. Features both indoor galleries and a beautiful outdoor sculpture garden.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Nasher_Sculpture_Center.jpg"
  },
  %{
    name: "Dallas Arboretum & Botanical Gardens",
    latitude: 32.822222,
    longitude: -96.717778,
    place_types: ["garden", "park", "attraction"],
    description: "66-acre botanical garden featuring stunning seasonal displays, especially famous for spring blooms during Dallas Blooms festival. Offers beautiful landscaped gardens with scenic White Rock Lake views.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Dallas_Arboretum_and_Botanical_Garden.jpg"
  },
  %{
    name: "Klyde Warren Park",
    latitude: 32.789167,
    longitude: -96.801944,
    place_types: ["park", "food_trucks", "events"],
    description: "Unique 5.2-acre park built over the Woodall Rodgers Freeway, connecting downtown and uptown Dallas. Features food trucks, free Wi-Fi, dog park, children's area, and performance pavilion.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Klyde_Warren_Park.jpg"
  },
  %{
    name: "Reunion Tower",
    latitude: 32.775278,
    longitude: -96.808889,
    place_types: ["observation_tower", "landmark", "attraction"],
    description: "Iconic 470-foot observation tower offering 360-degree panoramic views of Dallas from its GeO-Deck. Known locally as 'The Ball' due to its distinctive spherical shape.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Reunion_Tower_Dallas.JPG"
  }
]

IO.puts("🚀 Starting Dallas places import...")

{places_imported, places_skipped} = 
  Enum.reduce(places_data, {0, 0}, fn place_data, {imported, skipped} ->
    place_attrs = place_data
    |> Map.put(:latitude, Decimal.new(to_string(place_data.latitude)))
    |> Map.put(:longitude, Decimal.new(to_string(place_data.longitude)))
    |> Map.put(:cached_at, DateTime.utc_now())
    |> Map.put(:formatted_address, "Dallas, TX, USA")
    |> Map.put(:location_iq_place_id, "manual_#{place_data.name |> String.downcase() |> String.replace(~r/[^\w]/, "_")}")
    
    # Check if place already exists by name
    existing_place = Repo.get_by(Place, name: place_attrs.name)
    
    if existing_place do
      IO.puts("⏭️  Skipping existing place: #{place_attrs.name}")
      {imported, skipped + 1}
    else
      case Repo.insert(Place.manual_changeset(%Place{}, place_attrs)) do
        {:ok, place} ->
          IO.puts("✅ Imported: #{place.name}")
          {imported + 1, skipped}
          
        {:error, changeset} ->
          IO.puts("❌ Failed to import #{place_attrs.name}: #{inspect(changeset.errors)}")
          {imported, skipped + 1}
      end
    end
  end)

IO.puts("\n🎉 Import completed!")
IO.puts("✅ Places imported: #{places_imported}")
IO.puts("⏭️  Places skipped: #{places_skipped}")
IO.puts("📊 Total places in database: #{Repo.aggregate(Place, :count, :id)}")

# Add a few more places to complete the dataset
additional_places = [
  %{
    name: "Deep Ellum",
    latitude: 32.784722,
    longitude: -96.783333,
    place_types: ["neighborhood", "nightlife", "music", "art"],
    description: "Historic entertainment district east of downtown known for its vibrant nightlife, live music venues, street art, and eclectic mix of bars, restaurants, and shops.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Deep_Ellum_Dallas_street_art.jpg"
  },
  %{
    name: "Bishop Arts District",
    latitude: 32.734722,
    longitude: -96.825833,
    place_types: ["neighborhood", "shopping", "dining", "art"],
    description: "Walkable Oak Cliff district featuring independent shops, local restaurants, street art, and performing arts venues. Known for its community feel and the historic Kessler Theater.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Bishop_Arts_District_Dallas.jpg"
  },
  %{
    name: "AT&T Stadium",
    latitude: 32.747500,
    longitude: -97.092778,
    place_types: ["stadium", "sports", "entertainment"],
    description: "Home of the Dallas Cowboys, this architectural marvel features the world's largest high-definition video screen and retractable roof. Offers tours and hosts major events.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Cowboys_Stadium_full_view.jpg"
  },
  %{
    name: "Dallas World Aquarium",
    latitude: 32.783056,
    longitude: -96.805278,
    place_types: ["aquarium", "family_attraction", "zoo"],
    description: "Immersive experience combining aquatic exhibits with rainforest environments. Features a walk-through rainforest tunnel and diverse marine life in naturalistic habitats.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Dallas_World_Aquarium.jpg"
  },
  %{
    name: "White Rock Lake Park",
    latitude: 32.823333,
    longitude: -96.716667,
    place_types: ["park", "lake", "recreation"],
    description: "1,015-acre lake located 5 miles northeast of downtown Dallas, popular for walking, jogging, cycling, and kayaking. Offers scenic trails and wildlife viewing.",
    wiki_image: "https://en.wikipedia.org/wiki/File:White_Rock_Lake_Dallas.jpg"
  }
]

IO.puts("\n🔄 Adding additional Dallas places...")

{more_imported, more_skipped} = 
  Enum.reduce(additional_places, {0, 0}, fn place_data, {imported, skipped} ->
    place_attrs = place_data
    |> Map.put(:latitude, Decimal.new(to_string(place_data.latitude)))
    |> Map.put(:longitude, Decimal.new(to_string(place_data.longitude)))
    |> Map.put(:cached_at, DateTime.utc_now())
    |> Map.put(:formatted_address, "Dallas, TX, USA")
    |> Map.put(:location_iq_place_id, "manual_#{place_data.name |> String.downcase() |> String.replace(~r/[^\w]/, "_")}")
    
    existing_place = Repo.get_by(Place, name: place_attrs.name)
    
    if existing_place do
      IO.puts("⏭️  Skipping existing place: #{place_attrs.name}")
      {imported, skipped + 1}
    else
      case Repo.insert(Place.manual_changeset(%Place{}, place_attrs)) do
        {:ok, place} ->
          IO.puts("✅ Imported: #{place.name}")
          {imported + 1, skipped}
          
        {:error, changeset} ->
          IO.puts("❌ Failed to import #{place_attrs.name}: #{inspect(changeset.errors)}")
          {imported, skipped + 1}
      end
    end
  end)

IO.puts("\n🎯 Final results:")
IO.puts("✅ Total places imported: #{places_imported + more_imported}")
IO.puts("⏭️  Total places skipped: #{places_skipped + more_skipped}")
IO.puts("📊 Total places in database: #{Repo.aggregate(Place, :count, :id)}")