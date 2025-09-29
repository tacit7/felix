defmodule RouteWiseApi.PlaceholderImageService do
  @moduledoc """
  Centralized service for managing placeholder images for places and POIs.

  Provides intelligent fallback image selection based on place categories,
  with support for hierarchical category matching and robust fallback chains.

  ## Features

  - **Category Hierarchy**: Respects Google Places category specificity (waterfall > natural_feature > establishment)
  - **Robust Fallbacks**: Primary external URL + local SVG backup
  - **Easy Maintenance**: All placeholder logic centralized in one place
  - **Extensible**: Simple to add new categories without touching multiple files

  ## Usage

      # Get placeholder for a place with categories (prioritizes most specific)
      PlaceholderImageService.get_placeholder_image(["waterfall", "natural_feature"])
      # Returns waterfall-specific image

      # Get just the URL
      PlaceholderImageService.get_placeholder_url(["restaurant", "establishment"])
      # Returns restaurant image URL

  """

  require Logger

  @doc """
  Category to placeholder image mapping.

  Ordered by specificity - more specific categories should be checked first.
  Uses high-quality Unsplash images with consistent sizing and optimization.
  """
  @category_mappings %{
    # Natural Features (specific to general)
    "waterfall" => "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop&q=80",
    "beach" => "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&h=300&fit=crop&q=80",
    "mountain" => "https://images.unsplash.com/photo-1464822759356-8d6106e78f86?w=400&h=300&fit=crop&q=80",
    "lake" => "https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=400&h=300&fit=crop&q=80",
    "forest" => "https://images.unsplash.com/photo-1448375240586-882707db888b?w=400&h=300&fit=crop&q=80",
    "park" => "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop&q=80",
    "natural_feature" => "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop&q=80",

    # Food & Dining (specific to general)
    "cafe" => "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400&h=300&fit=crop&q=80",
    "bar" => "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=400&h=300&fit=crop&q=80",
    "meal_takeaway" => "https://images.unsplash.com/photo-1586816001966-79b736744398?w=400&h=300&fit=crop&q=80",
    "restaurant" => "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop&q=80",
    "food" => "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop&q=80",

    # Accommodation (specific to general)
    "hotel" => "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=300&fit=crop&q=80",
    "motel" => "https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=400&h=300&fit=crop&q=80",
    "resort" => "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=400&h=300&fit=crop&q=80",
    "lodging" => "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=300&fit=crop&q=80",

    # Shopping & Services
    "shopping_mall" => "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop&q=80",
    "store" => "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop&q=80",
    "gas_station" => "https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=400&h=300&fit=crop&q=80",
    "bank" => "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=400&h=300&fit=crop&q=80",
    "hospital" => "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=400&h=300&fit=crop&q=80",

    # Transportation
    "airport" => "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=400&h=300&fit=crop&q=80",
    "subway_station" => "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=300&fit=crop&q=80",
    "train_station" => "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=300&fit=crop&q=80",

    # Attractions & Entertainment
    "amusement_park" => "https://images.unsplash.com/photo-1594736797933-d0401ba2fe65?w=400&h=300&fit=crop&q=80",
    "museum" => "https://images.unsplash.com/photo-1564399580075-5dfe19c205f3?w=400&h=300&fit=crop&q=80",
    "zoo" => "https://images.unsplash.com/photo-1564349683136-77e08dba1ef7?w=400&h=300&fit=crop&q=80",
    "tourist_attraction" => "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop&q=80"
  }

  @doc """
  Default fallback when no category matches.
  """
  @default_placeholder "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop&q=80"

  @doc """
  Local fallback images for when external URLs fail.
  Uses your existing SVG placeholder files.
  """
  @local_fallbacks %{
    "poi" => "/api/images/fallbacks/poi-placeholder.svg",
    "default" => "/api/images/fallbacks/default-placeholder.svg",
    "icon" => "/api/images/fallbacks/default-icon.svg"
  }

  @doc """
  Get placeholder image data for a place based on its categories.

  Respects category hierarchy by checking most specific categories first.
  Returns structured data with primary and fallback URLs for robust loading.

  ## Parameters

  - `categories` - List of category strings for the place (most specific first recommended)
  - `opts` - Options (reserved for future use)

  ## Examples

      # Waterfall gets specific waterfall image
      iex> PlaceholderImageService.get_placeholder_image(["waterfall", "natural_feature"])
      %{
        primary: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop&q=80",
        fallback: "/api/images/fallbacks/poi-placeholder.svg",
        category_matched: "waterfall",
        source: "category_specific"
      }

      # Unknown category gets default
      iex> PlaceholderImageService.get_placeholder_image(["unknown_category"])
      %{
        primary: "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=300&fit=crop&q=80",
        fallback: "/api/images/fallbacks/poi-placeholder.svg",
        category_matched: nil,
        source: "default"
      }

  """
  def get_placeholder_image(categories, opts \\ [])

  def get_placeholder_image(categories, _opts) when is_list(categories) do
    case find_best_category_match(categories) do
      {category, url} ->
        %{
          primary: url,
          fallback: @local_fallbacks["poi"],
          category_matched: category,
          source: "category_specific"
        }

      nil ->
        %{
          primary: @default_placeholder,
          fallback: @local_fallbacks["poi"],
          category_matched: nil,
          source: "default"
        }
    end
  end

  def get_placeholder_image(category, opts) when is_binary(category) do
    get_placeholder_image([category], opts)
  end

  def get_placeholder_image(nil, opts), do: get_placeholder_image([], opts)
  def get_placeholder_image([], opts), do: get_placeholder_image([], opts)

  @doc """
  Get just the primary placeholder URL for a category.

  Simplified version that returns only the main image URL.
  Useful when you just need the image source without metadata.

  ## Examples

      iex> PlaceholderImageService.get_placeholder_url(["waterfall"])
      "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop&q=80"

      iex> PlaceholderImageService.get_placeholder_url(["restaurant", "establishment"])
      "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop&q=80"

  """
  def get_placeholder_url(categories) when is_list(categories) do
    get_placeholder_image(categories)
    |> Map.get(:primary)
  end

  def get_placeholder_url(category) when is_binary(category) do
    get_placeholder_url([category])
  end

  def get_placeholder_url(nil), do: get_placeholder_url([])

  @doc """
  Check if a category has a specific placeholder image.

  ## Examples

      iex> PlaceholderImageService.has_placeholder?("waterfall")
      true

      iex> PlaceholderImageService.has_placeholder?(["waterfall", "unknown"])
      true

      iex> PlaceholderImageService.has_placeholder?("unknown_category")
      false

  """
  def has_placeholder?(category) when is_binary(category) do
    Map.has_key?(@category_mappings, category)
  end

  def has_placeholder?(categories) when is_list(categories) do
    Enum.any?(categories, &has_placeholder?/1)
  end

  @doc """
  Get all available placeholder categories.

  Returns a list of all categories that have specific placeholder images.
  Useful for debugging or admin interfaces.
  """
  def available_categories do
    @category_mappings
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Get local fallback URL for a specific type.

  ## Examples

      iex> PlaceholderImageService.get_local_fallback("poi")
      "/api/images/fallbacks/poi-placeholder.svg"

  """
  def get_local_fallback(type) when is_binary(type) do
    Map.get(@local_fallbacks, type, @local_fallbacks["default"])
  end

  # Private Functions

  defp find_best_category_match(categories) do
    # Iterate through categories and find first match
    # This respects the order passed in, so specific categories should come first
    categories
    |> Enum.find_value(fn category ->
      case Map.get(@category_mappings, category) do
        nil -> nil
        url -> {category, url}
      end
    end)
  end
end