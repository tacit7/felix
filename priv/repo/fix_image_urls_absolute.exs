alias RouteWiseApi.Repo
alias RouteWiseApi.Places.DefaultImage
import Ecto.Query

# Fix image URLs to be absolute URLs pointing to backend server
IO.puts("🔧 Converting relative image URLs to absolute backend URLs...")

# Get backend URL from config
backend_url = "http://localhost:4001"

# Get all default images with relative URLs
default_images_to_fix =
  from(di in DefaultImage,
    where: like(di.image_url, "/images/%")
  )
  |> Repo.all()

IO.puts("📊 Found #{length(default_images_to_fix)} default images to convert to absolute URLs")

# Fix each image URL to be absolute
Enum.each(default_images_to_fix, fn default_image ->
  # Convert relative URL to absolute backend URL
  absolute_image_url = backend_url <> default_image.image_url

  # Update the record
  default_image
  |> DefaultImage.changeset(%{image_url: absolute_image_url})
  |> Repo.update!()
  |> then(fn updated_image ->
    IO.puts("✅ Fixed #{default_image.category}: #{default_image.image_url} → #{updated_image.image_url}")
  end)
end)

# Show updated statistics
updated_images =
  from(di in DefaultImage, where: like(di.image_url, "http://localhost:4001%"))
  |> Repo.all()

IO.puts("\n📈 Updated Absolute Image URLs (#{length(updated_images)}):")
Enum.each(updated_images, fn image ->
  IO.puts("  #{image.category}: #{image.image_url}")
end)

IO.puts("\n✅ Absolute image URL conversion complete!")