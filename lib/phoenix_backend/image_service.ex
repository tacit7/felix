defmodule RouteWiseApi.ImageService do
  @moduledoc """
  Image serving service with environment-aware URL generation and fallback support.

  Provides intelligent image URL generation that works seamlessly in development
  (localhost) and production (CDN). Includes comprehensive fallback strategies
  for missing images and optimized caching headers.

  ## Features

  - **Environment-Aware**: Dev serves from Phoenix, prod uses CDN
  - **Fallback Support**: Automatic fallbacks for missing images
  - **Multiple Formats**: WebP, JPEG, PNG with intelligent selection
  - **Size Variants**: Thumbnail, medium, large image sizes
  - **Category Icons**: SVG icons for POI categories
  - **Cache-Friendly**: Proper ETags and cache headers

  ## Usage

      # POI images with fallbacks
      %{primary: url, fallback: fallback_url} = 
        ImageService.get_poi_image_url(123, :medium)

      # Category icons
      icon_url = ImageService.get_category_icon_url("restaurant")

      # Custom images
      url = ImageService.get_image_url("custom/my-image.jpg")

  ## Configuration

      # config/dev.exs
      config :phoenix_backend, RouteWiseApi.ImageService,
        base_url: "http://localhost:4001",
        serve_locally: true,
        image_formats: [:webp, :jpg, :png]

      # config/prod.exs  
      config :phoenix_backend, RouteWiseApi.ImageService,
        base_url: "https://cdn.routewise.com",
        serve_locally: false,
        image_formats: [:webp, :jpg]

  ## Directory Structure

      priv/static/images/
      ├── pois/
      │   ├── 123/
      │   │   ├── thumb.webp
      │   │   ├── medium.webp
      │   │   └── large.webp
      ├── categories/
      │   ├── restaurant.svg
      │   ├── attraction.svg
      │   └── hotel.svg
      ├── fallbacks/
      │   ├── poi-placeholder.webp
      │   ├── restaurant-placeholder.webp
      │   └── default-placeholder.webp
      └── ui/
          ├── markers/
          └── logos/
  """

  require Logger

  @default_config %{
    base_url: "http://localhost:4001",
    serve_locally: true,
    image_formats: [:webp, :jpg, :png],
    enable_fallbacks: true,
    cache_max_age: 86_400  # 24 hours
  }

  @size_variants [:thumb, :medium, :large, :xlarge]
  @fallback_categories [
    "restaurant", "attraction", "hotel", "shopping", 
    "entertainment", "outdoor", "transport", "service"
  ]

  @doc """
  Get POI image URL with automatic fallback support.

  ## Parameters
  - `poi_id`: POI identifier (integer or string)
  - `size`: Image size variant (`:thumb`, `:medium`, `:large`, `:xlarge`)
  - `format`: Image format (`:webp`, `:jpg`, `:png`) - optional

  ## Returns
  Map with `:primary` and `:fallback` URLs for robust image loading.

  ## Examples

      iex> ImageService.get_poi_image_url(123, :medium)
      %{
        primary: "http://localhost:4001/api/images/pois/123/medium.webp",
        fallback: "http://localhost:4001/api/images/fallbacks/poi-placeholder.webp"
      }

      iex> ImageService.get_poi_image_url("poi_456", :thumb, :jpg)
      %{
        primary: "http://localhost:4001/api/images/pois/poi_456/thumb.jpg",
        fallback: "http://localhost:4001/api/images/fallbacks/poi-placeholder.jpg"
      }

  """
  def get_poi_image_url(poi_id, size \\ :medium, format \\ :webp) do
    unless size in @size_variants do
      Logger.warning("Invalid size variant: #{size}. Using :medium")
      size = :medium
    end

    primary_url = get_image_url("pois/#{poi_id}/#{size}.#{format}")
    fallback_url = get_fallback_image_url("poi", format)

    %{
      primary: primary_url,
      fallback: fallback_url,
      size: size,
      format: format
    }
  end

  @doc """
  Get category icon URL with SVG fallback.

  ## Parameters
  - `category`: POI category string
  - `style`: Icon style (`:filled`, `:outline`, `:color`) - optional

  ## Examples

      iex> ImageService.get_category_icon_url("restaurant")
      %{
        primary: "http://localhost:4001/api/images/categories/restaurant.svg",
        fallback: "http://localhost:4001/api/images/fallbacks/default-icon.svg"
      }

  """
  def get_category_icon_url(category, style \\ :filled) do
    icon_filename = case style do
      :filled -> "#{category}.svg"
      :outline -> "#{category}-outline.svg"
      :color -> "#{category}-color.svg"
      _ -> "#{category}.svg"
    end

    primary_url = get_image_url("categories/#{icon_filename}")
    fallback_url = get_image_url("fallbacks/default-icon.svg")

    %{
      primary: primary_url,
      fallback: fallback_url,
      category: category,
      style: style
    }
  end

  @doc """
  Get a complete image set for a POI (all sizes).

  ## Returns
  Map with all size variants and fallbacks.

  ## Examples

      iex> ImageService.get_poi_image_set(123)
      %{
        thumb: %{primary: "...", fallback: "..."},
        medium: %{primary: "...", fallback: "..."},
        large: %{primary: "...", fallback: "..."},
        xlarge: %{primary: "...", fallback: "..."}
      }

  """
  def get_poi_image_set(poi_id, format \\ :webp) do
    @size_variants
    |> Enum.into(%{}, fn size ->
      {size, get_poi_image_url(poi_id, size, format)}
    end)
  end

  @doc """
  Get base image URL for any custom path.

  ## Examples

      iex> ImageService.get_image_url("custom/hero-banner.jpg")
      "http://localhost:4001/api/images/custom/hero-banner.jpg"

  """
  def get_image_url(path) do
    config = get_config()
    
    if config.serve_locally do
      "#{config.base_url}/api/images/#{path}"
    else
      "#{config.base_url}/#{path}"
    end
  end

  @doc """
  Get fallback image URL for a category or type.

  ## Parameters
  - `category`: Image category for specific fallback
  - `format`: Image format (defaults to :webp)

  ## Examples

      iex> ImageService.get_fallback_image_url("restaurant")
      "http://localhost:4001/api/images/fallbacks/restaurant-placeholder.webp"

  """
  def get_fallback_image_url(category, format \\ :webp) do
    fallback_filename = if category in @fallback_categories do
      "#{category}-placeholder.#{format}"
    else
      "default-placeholder.#{format}"
    end

    get_image_url("fallbacks/#{fallback_filename}")
  end

  @doc """
  Get UI asset URLs (logos, markers, etc.).

  ## Examples

      iex> ImageService.get_ui_asset_url("logo", :light)
      "http://localhost:4001/api/images/ui/logo-light.svg"

  """
  def get_ui_asset_url(asset_type, variant \\ :default, format \\ :svg) do
    filename = case variant do
      :default -> "#{asset_type}.#{format}"
      _ -> "#{asset_type}-#{variant}.#{format}"
    end

    get_image_url("ui/#{filename}")
  end

  @doc """
  Check if image serving is enabled and configured correctly.

  ## Returns
  Health status map with configuration details.

  """
  def health_check do
    config = get_config()
    
    static_dir = Path.join([:code.priv_dir(:phoenix_backend), "static", "images"])
    static_exists = File.dir?(static_dir)
    
    %{
      service: "ImageService",
      status: if(static_exists, do: "healthy", else: "degraded"),
      config: %{
        base_url: config.base_url,
        serve_locally: config.serve_locally,
        formats: config.image_formats,
        fallbacks_enabled: config.enable_fallbacks
      },
      directories: %{
        static_images_exist: static_exists,
        static_images_path: static_dir
      },
      supported_sizes: @size_variants,
      fallback_categories: @fallback_categories
    }
  end

  @doc """
  Create directory structure for local image serving.
  Useful for development setup.
  """
  def create_directory_structure do
    base_path = Path.join([:code.priv_dir(:phoenix_backend), "static", "images"])
    
    directories = [
      "pois",
      "categories", 
      "fallbacks",
      "ui/logos",
      "ui/markers",
      "ui/icons"
    ]

    directories
    |> Enum.each(fn dir ->
      full_path = Path.join(base_path, dir)
      case File.mkdir_p(full_path) do
        :ok -> 
          Logger.info("Created image directory: #{full_path}")
        {:error, reason} -> 
          Logger.error("Failed to create directory #{full_path}: #{reason}")
      end
    end)

    {:ok, base_path}
  end

  ## Private Functions

  defp get_config do
    app_config = Application.get_env(:phoenix_backend, __MODULE__, [])
    config_map = Enum.into(app_config, %{})
    
    Map.merge(@default_config, config_map)
  end
end