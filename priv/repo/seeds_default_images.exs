alias RouteWiseApi.Repo
alias RouteWiseApi.Places.DefaultImage

# Default images seed data
default_images = [
  # Natural Features (specific to general)
  %{
    category: "waterfall",
    image_url: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Beautiful waterfall scene with cascading water",
    source: "unsplash"
  },
  %{
    category: "beach",
    image_url: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Pristine beach with clear blue water",
    source: "unsplash"
  },
  %{
    category: "mountain",
    image_url: "https://images.unsplash.com/photo-1464822759356-8d6106e78f86?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Majestic mountain landscape",
    source: "unsplash"
  },
  %{
    category: "lake",
    image_url: "https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Serene lake surrounded by nature",
    source: "unsplash"
  },
  %{
    category: "forest",
    image_url: "https://images.unsplash.com/photo-1448375240586-882707db888b?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Dense forest with tall trees",
    source: "unsplash"
  },
  %{
    category: "park",
    image_url: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Green park space with trees and pathways",
    source: "unsplash"
  },
  %{
    category: "natural_feature",
    image_url: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "General natural landscape feature",
    source: "unsplash"
  },

  # Food & Dining (specific to general)
  %{
    category: "cafe",
    image_url: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Cozy cafe interior with warm lighting",
    source: "unsplash"
  },
  %{
    category: "bar",
    image_url: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Modern bar with stylish ambiance",
    source: "unsplash"
  },
  %{
    category: "meal_takeaway",
    image_url: "https://images.unsplash.com/photo-1586816001966-79b736744398?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Takeaway food counter and ordering area",
    source: "unsplash"
  },
  %{
    category: "restaurant",
    image_url: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Elegant restaurant dining room",
    source: "unsplash"
  },
  %{
    category: "food",
    image_url: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "General food establishment",
    source: "unsplash"
  },

  # Accommodation (specific to general)
  %{
    category: "hotel",
    image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Luxurious hotel lobby and entrance",
    source: "unsplash"
  },
  %{
    category: "motel",
    image_url: "https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Classic motel exterior with parking",
    source: "unsplash"
  },
  %{
    category: "resort",
    image_url: "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Resort property with pool and amenities",
    source: "unsplash"
  },
  %{
    category: "lodging",
    image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "General lodging accommodation",
    source: "unsplash"
  },

  # Shopping & Services
  %{
    category: "shopping_mall",
    image_url: "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Modern shopping mall interior",
    source: "unsplash"
  },
  %{
    category: "store",
    image_url: "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Retail store front and shopping area",
    source: "unsplash"
  },
  %{
    category: "gas_station",
    image_url: "https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Gas station with fuel pumps",
    source: "unsplash"
  },
  %{
    category: "bank",
    image_url: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Modern bank building exterior",
    source: "unsplash"
  },
  %{
    category: "hospital",
    image_url: "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Hospital building and medical facility",
    source: "unsplash"
  },

  # Transportation
  %{
    category: "airport",
    image_url: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Airport terminal and departure area",
    source: "unsplash"
  },
  %{
    category: "subway_station",
    image_url: "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Modern subway station platform",
    source: "unsplash"
  },
  %{
    category: "train_station",
    image_url: "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Train station platform and tracks",
    source: "unsplash"
  },

  # Attractions & Entertainment
  %{
    category: "amusement_park",
    image_url: "https://images.unsplash.com/photo-1594736797933-d0401ba2fe65?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Colorful amusement park with rides",
    source: "unsplash"
  },
  %{
    category: "museum",
    image_url: "https://images.unsplash.com/photo-1564399580075-5dfe19c205f3?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Museum interior with exhibits",
    source: "unsplash"
  },
  %{
    category: "zoo",
    image_url: "https://images.unsplash.com/photo-1564349683136-77e08dba1ef7?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Zoo pathway with animal habitats",
    source: "unsplash"
  },
  %{
    category: "tourist_attraction",
    image_url: "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop&q=80",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Popular tourist landmark and attraction",
    source: "unsplash"
  }
]

# Insert default images
Enum.each(default_images, fn attrs ->
  case Repo.get_by(DefaultImage, category: attrs.category) do
    nil ->
      %DefaultImage{}
      |> DefaultImage.changeset(attrs)
      |> Repo.insert!()
      |> then(fn image ->
        IO.puts("✅ Created default image for category: #{image.category}")
      end)

    existing ->
      IO.puts("⚠️  Default image for category '#{existing.category}' already exists, skipping")
  end
end)

IO.puts("\n🎯 Default images seeding completed!")
IO.puts("📊 Total categories: #{length(default_images)}")