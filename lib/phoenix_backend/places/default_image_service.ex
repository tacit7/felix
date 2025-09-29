defmodule RouteWiseApi.Places.DefaultImageService do
  @moduledoc """
  Service for assigning default images to places during import and creation.

  Provides intelligent category-to-image matching that respects Google Places
  category hierarchy by prioritizing more specific categories first.

  ## Usage

      # Assign default image during place creation
      place_attrs = %{name: "El Yunque", categories: ["waterfall", "natural_feature"]}
      enhanced_attrs = DefaultImageService.assign_default_image(place_attrs)
      # Result: %{..., default_image_id: 1}

      # Update existing place with default image
      DefaultImageService.update_place_default_image(place)
  """

  require Logger
  import Ecto.Query
  alias RouteWiseApi.Repo
  alias RouteWiseApi.Places.DefaultImage
  alias RouteWiseApi.Places.Place

  @doc """
  Assigns a default image to place attributes based on categories.

  Respects category hierarchy by checking most specific categories first.
  Returns the original attrs if no matching default image is found.

  ## Examples

      iex> assign_default_image(%{categories: ["waterfall", "natural_feature"]})
      %{categories: ["waterfall", "natural_feature"], default_image_id: 1}

      iex> assign_default_image(%{categories: ["unknown_category"]})
      %{categories: ["unknown_category"]}  # No change if no match
  """
  def assign_default_image(place_attrs) when is_map(place_attrs) do
    categories = Map.get(place_attrs, :categories, [])

    case find_best_default_image(categories) do
      %DefaultImage{id: image_id} ->
        Map.put(place_attrs, :default_image_id, image_id)
      nil ->
        place_attrs
    end
  end

  @doc """
  Updates an existing place with the appropriate default image.

  Useful for retroactively assigning default images to existing places
  or updating them when categories change.

  ## Examples

      iex> place = Repo.get(Place, 123)
      iex> {:ok, updated_place} = update_place_default_image(place)
  """
  def update_place_default_image(%Place{} = place) do
    case find_best_default_image(place.categories || []) do
      %DefaultImage{id: image_id} ->
        place
        |> Place.changeset(%{default_image_id: image_id})
        |> Repo.update()

      nil ->
        {:ok, place}  # No change if no matching image found
    end
  end

  @doc """
  Updates all places without default images based on their categories.

  Useful for bulk assignment of default images to existing data.
  Returns statistics about the operation.
  """
  def bulk_assign_default_images do
    Logger.info("🖼️  Starting bulk assignment of default images to places...")

    places_without_images =
      from(p in Place,
        where: is_nil(p.default_image_id),
        select: p
      )
      |> Repo.all()

    total_places = length(places_without_images)
    Logger.info("📊 Found #{total_places} places without default images")

    {updated_count, failed_count} =
      places_without_images
      |> Enum.reduce({0, 0}, fn place, {updated, failed} ->
        case update_place_default_image(place) do
          {:ok, %Place{default_image_id: nil}} ->
            {updated, failed}  # No image assigned, but no error
          {:ok, %Place{}} ->
            {updated + 1, failed}
          {:error, _reason} ->
            {updated, failed + 1}
        end
      end)

    Logger.info("✅ Bulk assignment completed: #{updated_count} updated, #{failed_count} failed")

    %{
      total_places: total_places,
      updated_count: updated_count,
      failed_count: failed_count,
      no_match_count: total_places - updated_count - failed_count
    }
  end

  @doc """
  Gets all available default image categories.

  Returns a list of categories that have default images available.
  """
  def available_categories do
    DefaultImage.available_categories()
  end

  @doc """
  Checks if any categories have a corresponding default image.

  ## Examples

      iex> has_default_image?(["waterfall", "natural_feature"])
      true

      iex> has_default_image?(["unknown_category"])
      false
  """
  def has_default_image?(categories) when is_list(categories) do
    find_best_default_image(categories) != nil
  end

  @doc """
  Gets the default image URL for a list of categories.

  Returns the primary image URL from the best matching default image.
  """
  def get_default_image_url(categories) when is_list(categories) do
    case find_best_default_image(categories) do
      %DefaultImage{image_url: url} -> {:ok, url}
      nil -> :error
    end
  end

  @doc """
  Gets the fallback image URL for a list of categories.

  Returns the fallback image URL from the best matching default image.
  """
  def get_fallback_image_url(categories) when is_list(categories) do
    case find_best_default_image(categories) do
      %DefaultImage{fallback_url: url} when not is_nil(url) -> {:ok, url}
      nil -> :error
    end
  end

  # Private Functions

  @doc false
  def find_best_default_image(categories) when is_list(categories) do
    # Use DefaultImage's built-in hierarchy logic
    DefaultImage.for_categories(categories)
  end

  @doc """
  Creates a Mix task helper for bulk operations.

  Can be called from a Mix task like:

      mix run -e "RouteWiseApi.Places.DefaultImageService.bulk_assign_default_images()"
  """
  def run_bulk_assignment do
    case bulk_assign_default_images() do
      %{updated_count: updated, failed_count: 0} when updated > 0 ->
        IO.puts("🎯 Success: #{updated} places assigned default images")

      %{updated_count: 0, no_match_count: no_match} when no_match > 0 ->
        IO.puts("ℹ️  No changes: #{no_match} places have no matching default images")

      %{updated_count: updated, failed_count: failed} when failed > 0 ->
        IO.puts("⚠️  Partial success: #{updated} updated, #{failed} failed")

      %{total_places: 0} ->
        IO.puts("✅ All places already have default images assigned")
    end
  end
end