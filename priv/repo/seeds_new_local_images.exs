alias RouteWiseApi.Repo
alias RouteWiseApi.Places.DefaultImage
import Ecto.Query

# Add new local image categories to database
new_image_updates = [
  # High priority categories that were missing
  %{
    category: "gas_station",
    image_url: "/api/images/categories/gas-station.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Modern gas station with fuel pumps",
    source: "local"
  },
  %{
    category: "museum",
    image_url: "/api/images/categories/museum.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Museum building with exhibits and displays",
    source: "local"
  },
  %{
    category: "natural_feature",
    image_url: "/api/images/categories/natural-feature.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Beautiful natural landscape feature",
    source: "local"
  },
  %{
    category: "park",
    image_url: "/api/images/categories/park.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Public park with green spaces and trees",
    source: "local"
  },
  %{
    category: "amusement_park",
    image_url: "/api/images/categories/theme-park.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Theme park with rides and entertainment",
    source: "local"
  },
  %{
    category: "tourist_attraction",
    image_url: "/api/images/categories/tourist-attraction.jpg",
    fallback_url: "/api/images/fallbacks/poi-placeholder.svg",
    description: "Popular tourist attraction and landmark",
    source: "local"
  }
]

IO.puts("🎯 Adding #{length(new_image_updates)} new local image categories...")

# Add new categories or update existing ones
Enum.each(new_image_updates, fn attrs ->
  case Repo.get_by(DefaultImage, category: attrs.category) do
    nil ->
      # Create new entry
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

# Show updated statistics
total_categories = Repo.aggregate(DefaultImage, :count, :id)
local_categories = from(di in DefaultImage, where: di.source == "local") |> Repo.aggregate(:count, :id)
unsplash_categories = from(di in DefaultImage, where: di.source == "unsplash") |> Repo.aggregate(:count, :id)

IO.puts("\n📊 Database Image Categories Updated:")
IO.puts("  Total categories: #{total_categories}")
IO.puts("  Local images: #{local_categories}")
IO.puts("  Unsplash images: #{unsplash_categories}")
IO.puts("  Local image files: 15 (9 original + 6 new)")

IO.puts("\n💾 Updated local image categories:")
new_image_updates
|> Enum.map(& &1.category)
|> Enum.each(&IO.puts("  • #{&1}"))

IO.puts("\n✅ New local images integration complete!")