alias RouteWiseApi.Repo
alias RouteWiseApi.Places.{Place, DefaultImage}
import Ecto.Query

# Script to analyze places without placeholders and map them to existing local images
IO.puts("🔍 Analyzing places without placeholder images...")

# Get all available local images (15 total)
available_categories = [
  "waterfall", "beach", "forest", "cafe", "bar", "restaurant",
  "hotel", "airport", "camping", "gas_station", "museum",
  "natural_feature", "park", "amusement_park", "tourist_attraction"
]

IO.puts("📊 Available local image categories: #{inspect(available_categories)}")

# Category mapping rules - only map categories that make logical sense
category_mappings = %{
  # Food & Dining - good matches only
  "food" => "restaurant",
  "meal_delivery" => "restaurant",
  "meal_takeaway" => "restaurant",
  "bakery" => "cafe",

  # Accommodation - direct matches
  "lodging" => "hotel",

  # Transportation - airports only for other transport
  "subway_station" => "airport",
  "train_station" => "airport",

  # Attractions - map to specific categories
  "establishment" => "tourist_attraction"
}

IO.puts("🗺️  Category mapping rules:")
Enum.each(category_mappings, fn {from, to} ->
  IO.puts("  #{from} → #{to}")
end)

# Find places without default images
places_without_images =
  from(p in Place,
    where: is_nil(p.default_image_id),
    select: %{id: p.id, name: p.name, categories: p.categories}
  )
  |> Repo.all()

IO.puts("\n📋 Found #{length(places_without_images)} places without placeholder images")

# Analyze categories and create assignments using Enum.reduce for proper accumulation
{assignments, unmatched_places} = Enum.reduce(places_without_images, {[], []}, fn place, {assignments_acc, unmatched_acc} ->
  categories = place.categories || []

  # Try to find a direct match first
  direct_match = Enum.find(categories, &(&1 in available_categories))

  if direct_match do
    # Direct category match
    case Repo.get_by(DefaultImage, category: direct_match) do
      %DefaultImage{id: image_id} ->
        assignment = %{place_id: place.id, place_name: place.name, category: direct_match, image_id: image_id}
        {[assignment | assignments_acc], unmatched_acc}
      nil ->
        {assignments_acc, [place | unmatched_acc]}
    end
  else
    # Try mapped categories
    mapped_category = Enum.find_value(categories, fn cat ->
      Map.get(category_mappings, cat)
    end)

    if mapped_category do
      case Repo.get_by(DefaultImage, category: mapped_category) do
        %DefaultImage{id: image_id} ->
          original_category = Enum.find(categories, &Map.has_key?(category_mappings, &1))
          assignment = %{place_id: place.id, place_name: place.name, category: "#{original_category} → #{mapped_category}", image_id: image_id}
          {[assignment | assignments_acc], unmatched_acc}
        nil ->
          {assignments_acc, [place | unmatched_acc]}
      end
    else
      {assignments_acc, [place | unmatched_acc]}
    end
  end
end)

assignments = Enum.reverse(assignments)
unmatched_places = Enum.reverse(unmatched_places)

IO.puts("\n✅ Successful mappings (#{length(assignments)}):")
Enum.each(assignments, fn assignment ->
  IO.puts("  #{assignment.place_name} → #{assignment.category}")
end)

IO.puts("\n❌ Unmatched places (#{length(unmatched_places)}):")
Enum.each(unmatched_places, fn place ->
  categories_str = if place.categories && length(place.categories) > 0, do: inspect(place.categories), else: "no categories"
  IO.puts("  #{place.name} (#{categories_str})")
end)

# Show category frequency for unmatched places
unmatched_categories =
  unmatched_places
  |> Enum.flat_map(fn place -> place.categories || [] end)
  |> Enum.frequencies()
  |> Enum.sort_by(fn {_cat, count} -> -count end)

IO.puts("\n📊 Most common categories in unmatched places:")
Enum.take(unmatched_categories, 10) |> Enum.each(fn {category, count} ->
  IO.puts("  #{category}: #{count} places")
end)

# Ask for confirmation before applying changes
IO.puts("\n🚨 Ready to apply #{length(assignments)} placeholder assignments?")
IO.puts("This will only assign placeholders where we have good category matches.")
IO.puts("Places without good matches will remain null (no forced assignments).")

response = IO.gets("Continue? (y/N): ") |> String.trim() |> String.downcase()

if response in ["y", "yes"] do
  IO.puts("\n🔄 Applying assignments...")

  success_count = 0
  error_count = 0

  Enum.each(assignments, fn assignment ->
    case Repo.get(Place, assignment.place_id) do
      %Place{} = place ->
        case Ecto.Changeset.change(place, %{default_image_id: assignment.image_id}) |> Repo.update() do
          {:ok, _updated_place} ->
            success_count = success_count + 1
            IO.write("✅")
          {:error, changeset} ->
            error_count = error_count + 1
            IO.puts("\n❌ Failed to update #{assignment.place_name}: #{inspect(changeset.errors)}")
        end
      nil ->
        error_count = error_count + 1
        IO.puts("\n❌ Place not found: #{assignment.place_name}")
    end
  end)

  IO.puts("\n\n🎯 Assignment Results:")
  IO.puts("  ✅ Successfully assigned: #{success_count}")
  IO.puts("  ❌ Failed: #{error_count}")
  IO.puts("  🔍 Remaining null (no good match): #{length(unmatched_places)}")

  # Show final statistics
  total_places = from(p in Place, select: count()) |> Repo.one()
  places_with_images = from(p in Place, where: not is_nil(p.default_image_id), select: count()) |> Repo.one()
  places_without_images = total_places - places_with_images
  coverage_percentage = Float.round(places_with_images / total_places * 100, 1)

  IO.puts("\n📈 Final Coverage Statistics:")
  IO.puts("  Total places: #{total_places}")
  IO.puts("  Places with images: #{places_with_images}")
  IO.puts("  Places without images (null): #{places_without_images}")
  IO.puts("  Coverage: #{coverage_percentage}%")
else
  IO.puts("❌ Assignment cancelled by user")
end

IO.puts("\n✅ Analysis complete!")