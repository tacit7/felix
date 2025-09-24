defmodule Mix.Tasks.PopulateBoundingBoxes do
  @moduledoc """
  Populates bounding box data for locations using OpenStreetMap Nominatim API.

  Usage:
    mix populate_bounding_boxes
    mix populate_bounding_boxes --force     # Force update all locations
  """

  use Mix.Task

  alias RouteWiseApi.{Repo, OSMGeocoding}
  alias RouteWiseApi.Places.Location
  import Ecto.Query

  @shortdoc "Populate bounding box data for locations from OSM Nominatim"

  def run(args) do
    # Start the app to ensure HTTP and database are available
    Mix.Task.run("app.start")

    force_update = Enum.member?(args, "--force")

    # Find locations that need bounding box data
    query = if force_update do
      from(l in Location, select: l)
    else
      from(l in Location,
        where: is_nil(l.bbox_north) or is_nil(l.bbox_south) or
               is_nil(l.bbox_east) or is_nil(l.bbox_west),
        select: l
      )
    end

    locations = Repo.all(query)

    IO.puts("📍 Found #{length(locations)} locations #{if force_update, do: "to update", else: "needing bounding box data"}")

    if length(locations) == 0 do
      IO.puts("✨ All locations already have bounding box data!")
    else
      # Process each location with rate limiting
      {success_count, error_count} =
        Enum.with_index(locations, 1)
        |> Enum.reduce({0, 0}, fn {location, index}, {success, errors} ->
          IO.puts("[#{index}/#{length(locations)}] Processing: #{location.name}")

          case OSMGeocoding.update_city_bounds(location) do
            {:ok, _updated_location} ->
              IO.puts("  ✅ Updated bounds for #{location.name}")
              {success + 1, errors}
            {:error, reason} ->
              IO.puts("  ❌ Failed to update #{location.name}: #{inspect(reason)}")
              {success, errors + 1}
          end

          # Rate limiting: 1.1 second delay between requests (respectful to free OSM service)
          if index < length(locations) do
            :timer.sleep(1100)
          end

          {success, errors}
        end)

      IO.puts("""

      🎉 Finished populating bounding box data
      ✅ Successfully updated: #{success_count}
      ❌ Failed to update: #{error_count}
      """)
    end
  end
end