# Import script for Isla Verde, Puerto Rico attractions
alias RouteWiseApi.{Repo, Places.Place}

# Isla Verde attractions data based on our comprehensive scraping
places_data = [
  %{
    name: "El Yunque National Forest",
    latitude: 18.3119,
    longitude: -65.8031,
    place_types: ["nature", "forest", "hiking", "waterfalls"],
    description: "The only tropical rainforest in the US National Forest System, featuring waterfalls, hiking trails, and diverse wildlife. Popular trails include La Mina Falls and Mount Britton Tower with stunning views of the forest canopy.",
    wiki_image: "https://en.wikipedia.org/wiki/File:El_Yunque_National_Forest_Puerto_Rico.jpg"
  },
  %{
    name: "Isla Verde Beach",
    latitude: 18.4567,
    longitude: -66.0321,
    place_types: ["beach", "swimming", "water_sports", "urban_beach"],
    description: "Popular urban beach strip with hotels, restaurants, and water sports. Known for its golden sand and clear blue waters, perfect for swimming, sunbathing, and beachfront dining experiences.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Isla_Verde_Beach_Puerto_Rico.jpg"
  },
  %{
    name: "Laguna Grande Bioluminescent Bay",
    latitude: 18.3847,
    longitude: -65.8203,
    place_types: ["nature", "bioluminescence", "kayaking", "night_tours"],
    description: "Bioluminescent lagoon offering magical night kayak tours where the water glows with microscopic organisms called dinoflagellates. One of only a few bioluminescent bays in the world.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Bioluminescent_Bay_Puerto_Rico.jpg"
  },
  %{
    name: "Piñones Food Kioskos",
    latitude: 18.4789,
    longitude: -65.9645,
    place_types: ["food", "local_culture", "beach", "dining"],
    description: "Coastal area known for its kioskos (food stands) serving traditional Puerto Rican food. Great for trying local specialties like alcapurrias, bacalaitos, and fresh seafood while enjoying beach views.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Pinones_Puerto_Rico_Food_Kiosks.jpg"
  },
  %{
    name: "Flamenco Beach, Culebra",
    latitude: 18.3161,
    longitude: -65.3053,
    place_types: ["beach", "snorkeling", "pristine", "world_class"],
    description: "One of the world's most beautiful beaches located on Culebra island. Crystal clear waters and pristine white sand make it a must-visit destination. Accessible by ferry or small plane.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Flamenco_Beach_Culebra_Puerto_Rico.jpg"
  },
  %{
    name: "Balneario de Carolina",
    latitude: 18.4655,
    longitude: -66.0004,
    place_types: ["beach", "family_friendly", "public_beach", "swimming"],
    description: "Beautiful public beach in Carolina with calm waters, perfect for families. Features amenities like restrooms, showers, picnic areas, and lifeguards on duty during peak hours.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Balneario_Carolina_Puerto_Rico.jpg"
  },
  %{
    name: "Las Cabezas de San Juan Nature Reserve",
    latitude: 18.3736,
    longitude: -65.6242,
    place_types: ["nature", "reserve", "lighthouse", "ecosystems"],
    description: "Nature reserve featuring diverse ecosystems including dry forest, mangroves, lagoons, and coral reefs. Home to El Faro lighthouse with panoramic views of the coastline.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Las_Cabezas_San_Juan_Puerto_Rico.jpg"
  },
  %{
    name: "Mosquito Bay, Vieques",
    latitude: 18.0889,
    longitude: -65.4736,
    place_types: ["nature", "bioluminescent", "world_wonder", "kayaking"],
    description: "The brightest bioluminescent bay in the world, located on Vieques island. Best experienced on dark, moonless nights for maximum glow effect. Protected ecosystem requiring special permits.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Mosquito_Bay_Vieques_Bioluminescent.jpg"
  },
  %{
    name: "Old San Juan",
    latitude: 18.4655,
    longitude: -66.1057,
    place_types: ["historic", "colonial", "culture", "walking"],
    description: "Historic colonial district with colorful buildings, cobblestone streets, and centuries-old forts. Rich in history and culture with excellent dining, El Morro fortress, and vibrant nightlife.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Old_San_Juan_Puerto_Rico_Colorful_Buildings.jpg"
  },
  %{
    name: "Casa Bacardí",
    latitude: 18.4655,
    longitude: -66.0875,
    place_types: ["attraction", "distillery", "tours", "rum"],
    description: "Historic rum distillery offering tours and tastings. Learn about the history of Bacardí rum and enjoy samples of their finest products. Accessible by ferry from Old San Juan.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Casa_Bacardi_Puerto_Rico.jpg"
  },
  %{
    name: "Condado Beach",
    latitude: 18.4655,
    longitude: -66.0737,
    place_types: ["beach", "upscale", "dining", "shopping"],
    description: "Upscale beach area in San Juan with luxury hotels, fine dining, and shopping. Popular with both locals and tourists for its vibrant atmosphere and excellent restaurants.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Condado_Beach_San_Juan_Puerto_Rico.jpg"
  },
  %{
    name: "Camuy Caves",
    latitude: 18.4789,
    longitude: -66.8542,
    place_types: ["nature", "caves", "underground", "tours"],
    description: "One of the world's largest cave systems with underground rivers and impressive limestone formations. Guided tours available through the spectacular caverns and underground chambers.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Camuy_Caves_Puerto_Rico.jpg"
  },
  %{
    name: "Arecibo Observatory",
    latitude: 18.3544,
    longitude: -66.7528,
    place_types: ["science", "observatory", "education", "astronomy"],
    description: "Famous radio telescope featured in movies like Contact and GoldenEye. Educational visitor center with exhibits about space science, astronomy, and the search for extraterrestrial life.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Arecibo_Observatory_Puerto_Rico.jpg"
  },
  %{
    name: "Cueva Ventana",
    latitude: 18.4123,
    longitude: -66.7234,
    place_types: ["nature", "cave", "views", "tours"],
    description: "Cave offering spectacular views of the northern coast through a natural window opening. Guided tours explain the geological formations and provide stunning photo opportunities.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Cueva_Ventana_Puerto_Rico.jpg"
  },
  %{
    name: "Ponce Historic District",
    latitude: 18.0111,
    longitude: -66.6140,
    place_types: ["historic", "architecture", "museums", "culture"],
    description: "Charming southern city with neoclassical architecture, museums, and the famous Ponce Cathedral. Known as the Pearl of the South with beautiful plazas and cultural attractions.",
    wiki_image: "https://en.wikipedia.org/wiki/File:Ponce_Historic_District_Puerto_Rico.jpg"
  }
]

IO.puts("🏖️ Starting Isla Verde/Puerto Rico attractions import...")

{places_imported, places_skipped} = 
  Enum.reduce(places_data, {0, 0}, fn place_data, {imported, skipped} ->
    place_attrs = place_data
    |> Map.put(:latitude, Decimal.new(to_string(place_data.latitude)))
    |> Map.put(:longitude, Decimal.new(to_string(place_data.longitude)))
    |> Map.put(:cached_at, DateTime.utc_now())
    |> Map.put(:formatted_address, "Puerto Rico")
    |> Map.put(:location_iq_place_id, "manual_pr_#{place_data.name |> String.downcase() |> String.replace(~r/[^\w]/, "_")}")
    
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

IO.puts("\n🎉 Isla Verde/Puerto Rico import completed!")
IO.puts("✅ Places imported: #{places_imported}")
IO.puts("⏭️  Places skipped: #{places_skipped}")
IO.puts("📊 Total places in database: #{Repo.aggregate(Place, :count, :id)}")

# Add TripAdvisor location data for future reference
IO.puts("\n📍 TripAdvisor Location Data:")
IO.puts("Location ID: 2665727")
IO.puts("Coordinates: 18.448399, -66.01663")
IO.puts("Hierarchy: Carolina, Puerto Rico, Caribbean, North America")
IO.puts("Attractions URL: /Attractions-g2665727-Activities-Isla_Verde_Carolina_Puerto_Rico.html")