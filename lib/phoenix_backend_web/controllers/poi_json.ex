defmodule RouteWiseApiWeb.POIJSON do
  import RouteWiseApiWeb.CacheHelpers
  alias RouteWiseApi.Trips.POI
  alias RouteWiseApi.ImageService

  @doc """
  Renders a list of POIs.
  """
  def index(%{pois: pois} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: for(poi <- pois, do: data(poi))}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders a single POI.
  """
  def show(%{poi: poi} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: data(poi)}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders POI categories.
  """
  def categories(%{categories: categories} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: categories}
    |> maybe_add_cache_meta(cache_info)
  end

  defp data(%POI{} = poi) do
    # Get image URLs from our image service
    images = ImageService.get_poi_image_set(poi.id)
    category_icon = ImageService.get_category_icon_url(poi.category || "default")

    %{
      id: poi.id,
      name: poi.name,
      description: poi.description,
      category: poi.category,
      rating: poi.rating,
      review_count: poi.review_count,
      time_from_start: poi.time_from_start,
      # Legacy image_url for backward compatibility
      image_url: poi.image_url,
      # New enhanced image structure
      images: %{
        thumbnail: images.thumb,
        medium: images.medium,
        large: images.large,
        xlarge: images.xlarge
      },
      category_icon: category_icon,
      place_id: poi.place_id,
      address: poi.address,
      price_level: poi.price_level,
      is_open: poi.is_open,
      latitude: poi.latitude,
      longitude: poi.longitude,
      inserted_at: poi.inserted_at,
      updated_at: poi.updated_at
    }
  end
end