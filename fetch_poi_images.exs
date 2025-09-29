# Script to fetch and cache Google Places images for POIs
import Ecto.Query
alias RouteWiseApi.{Repo, GoogleImageService}
alias RouteWiseApi.Trips.POI

# Step 1: Query database for POIs with Google Place IDs
IO.puts("📊 Step 1: Finding POIs with Google Place IDs...")

poi_query = from p in POI,
  where: not is_nil(p.place_id),
  limit: 3,
  select: {p.id, p.name, p.place_id}

pois = Repo.all(poi_query)

IO.puts("Found #{length(pois)} POIs with Google Place IDs:")
Enum.each(pois, fn {id, name, place_id} ->
  IO.puts("  #{id}: #{name} (#{place_id})")
end)

# Step 2: Fetch and cache images for these POIs
IO.puts("\n🖼️  Step 2: Fetching and caching images...")

results = Enum.map(pois, fn {poi_id, name, place_id} ->
  IO.puts("Processing: #{name}...")

  case GoogleImageService.fetch_and_cache_poi_image(poi_id, place_id) do
    {:ok, result} ->
      IO.puts("✅ Success for #{name}: #{inspect(result)}")
      {:ok, poi_id, name, result}
    {:error, reason} ->
      IO.puts("❌ Failed for #{name}: #{inspect(reason)}")
      {:error, poi_id, name, reason}
  end
end)

# Step 3: Check filesystem for cached images
IO.puts("\n📁 Step 3: Verifying cached images on filesystem...")

# Check the priv/static/images/pois directory structure
images_dir = Path.join([Application.app_dir(:phoenix_backend, "priv"), "static", "images", "pois"])
IO.puts("Images directory: #{images_dir}")

if File.exists?(images_dir) do
  poi_dirs = File.ls!(images_dir)
  IO.puts("Found POI image directories: #{inspect(poi_dirs)}")

  Enum.each(poi_dirs, fn poi_dir ->
    poi_path = Path.join(images_dir, poi_dir)
    if File.dir?(poi_path) do
      files = File.ls!(poi_path)
      IO.puts("  POI #{poi_dir}: #{inspect(files)}")
    end
  end)
else
  IO.puts("❌ Images directory does not exist: #{images_dir}")
end

# Summary
IO.puts("\n📋 Summary:")
successful = Enum.count(results, fn {status, _, _, _} -> status == :ok end)
failed = Enum.count(results, fn {status, _, _, _} -> status == :error end)

IO.puts("✅ Successful: #{successful}")
IO.puts("❌ Failed: #{failed}")
IO.puts("Total processed: #{successful + failed}")