alias RouteWiseApi.Repo
alias RouteWiseApi.Places.DefaultImage
import Ecto.Query

# Fix image URLs to remove /api prefix since Phoenix serves static files without it
IO.puts("🔧 Fixing default image URLs to match Phoenix static file serving...")

# Get all default images with /api prefix
default_images_to_fix =
  from(di in DefaultImage,
    where: like(di.image_url, "/api/images/%")
  )
  |> Repo.all()

IO.puts("📊 Found #{length(default_images_to_fix)} default images to fix")

# Fix each image URL
Enum.each(default_images_to_fix, fn default_image ->
  # Remove /api prefix from image_url
  fixed_image_url = String.replace(default_image.image_url, "/api/images/", "/images/")

  # Update the record
  default_image
  |> DefaultImage.changeset(%{image_url: fixed_image_url})
  |> Repo.update!()
  |> then(fn updated_image ->
    IO.puts("✅ Fixed #{default_image.category}: #{default_image.image_url} → #{updated_image.image_url}")
  end)
end)

# Show updated statistics
updated_images = Repo.all(DefaultImage)
IO.puts("\n📈 Updated Image URLs:")
Enum.each(updated_images, fn image ->
  IO.puts("  #{image.category}: #{image.image_url}")
end)

IO.puts("\n✅ Default image URL fixes complete!")