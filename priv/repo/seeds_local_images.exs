alias RouteWiseApi.Repo
alias RouteWiseApi.Places.DefaultImage

# Update existing default images to use local files where available
local_image_updates = [
  # Natural Features
  %{
    category: "waterfall",
    image_url: "/api/images/categories/waterfall.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Beautiful waterfall scene with cascading water",
    source: "local"
  },
  %{
    category: "beach",
    image_url: "/api/images/categories/beach.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Pristine beach with clear blue water",
    source: "local"
  },
  %{
    category: "forest",
    image_url: "/api/images/categories/forest.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Dense forest with tall trees",
    source: "local"
  },

  # Food & Dining
  %{
    category: "cafe",
    image_url: "/api/images/categories/cafe.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Cozy cafe interior with warm lighting",
    source: "local"
  },
  %{
    category: "bar",
    image_url: "/api/images/categories/bar.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Modern bar with stylish ambiance",
    source: "local"
  },
  %{
    category: "restaurant",
    image_url: "/api/images/categories/restaurant.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Elegant restaurant dining room",
    source: "local"
  },

  # Accommodation
  %{
    category: "hotel",
    image_url: "/api/images/categories/hotel.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Luxurious hotel lobby and entrance",
    source: "local"
  },

  # Transportation
  %{
    category: "airport",
    image_url: "/api/images/categories/airport.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Airport terminal and departure area",
    source: "local"
  },

  # Outdoor Activities (new category from your images)
  %{
    category: "camping",
    image_url: "/api/images/categories/camping.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Camping site with tents and outdoor activities",
    source: "local"
  }
]

# Update existing images with local versions
Enum.each(local_image_updates, fn attrs ->
  case Repo.get_by(DefaultImage, category: attrs.category) do
    nil ->
      # Create new entry if it doesn't exist
      %DefaultImage{}
      |> DefaultImage.changeset(attrs)
      |> Repo.insert!()
      |> then(fn image ->
        IO.puts("✅ Created new local image for category: #{image.category}")
      end)

    existing ->
      # Update existing entry with local image
      existing
      |> DefaultImage.changeset(attrs)
      |> Repo.update!()
      |> then(fn image ->
        IO.puts("🔄 Updated to local image for category: #{image.category}")
      end)
  end
end)

IO.puts("\n🎯 Local image updates completed!")
IO.puts("📊 Updated categories: #{length(local_image_updates)}")
IO.puts("💾 Images now served from: priv/static/images/categories/")