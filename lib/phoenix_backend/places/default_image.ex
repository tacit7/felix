defmodule RouteWiseApi.Places.DefaultImage do
  @moduledoc """
  Schema for default placeholder images used by places.

  Provides category-specific placeholder images that can be assigned to places
  during import or updated through the admin interface.

  ## Schema Fields

  - `category`: Unique category identifier (e.g., "waterfall", "restaurant")
  - `image_url`: Primary image URL (typically Unsplash or external CDN)
  - `fallback_url`: Local fallback image URL (SVG placeholders)
  - `description`: Human-readable description of the image
  - `source`: Image source ("unsplash", "local", "custom")
  - `is_active`: Whether this image is currently active

  ## Usage

      # Find image for a category
      DefaultImage.for_category("waterfall")

      # Create new default image
      %DefaultImage{}
      |> DefaultImage.changeset(%{
        category: "waterfall",
        image_url: "https://images.unsplash.com/...",
        description: "Beautiful waterfall scene"
      })

  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias RouteWiseApi.Repo
  alias RouteWiseApi.Places.Place

  @type t :: %__MODULE__{
          id: integer(),
          category: String.t(),
          image_url: String.t(),
          fallback_url: String.t() | nil,
          description: String.t() | nil,
          source: String.t(),
          is_active: boolean(),
          places: [Place.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "default_images" do
    field :category, :string
    field :image_url, :string
    field :fallback_url, :string
    field :description, :string
    field :source, :string, default: "unsplash"
    field :is_active, :boolean, default: true

    has_many :places, Place

    timestamps()
  end

  @doc """
  Changeset for creating or updating default images.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(default_image, attrs) do
    default_image
    |> cast(attrs, [:category, :image_url, :fallback_url, :description, :source, :is_active])
    |> validate_required([:category, :image_url])
    |> validate_length(:category, min: 2, max: 100)
    |> validate_url(:image_url)
    |> validate_url(:fallback_url, allow_nil: true)
    |> validate_inclusion(:source, ["unsplash", "local", "custom"])
    |> unique_constraint(:category)
  end

  @doc """
  Find a default image for a specific category.

  Returns the active default image for the given category, or nil if none exists.

  ## Examples

      iex> DefaultImage.for_category("waterfall")
      %DefaultImage{category: "waterfall", image_url: "https://..."}

      iex> DefaultImage.for_category("nonexistent")
      nil

  """
  @spec for_category(String.t()) :: t() | nil
  def for_category(category) when is_binary(category) do
    from(di in __MODULE__,
      where: di.category == ^category and di.is_active == true
    )
    |> Repo.one()
  end

  @doc """
  Find the best default image for a list of categories.

  Checks categories in order and returns the first match.
  Respects category hierarchy (most specific first).

  ## Examples

      iex> DefaultImage.for_categories(["waterfall", "natural_feature"])
      %DefaultImage{category: "waterfall", ...}

      iex> DefaultImage.for_categories(["unknown", "restaurant"])
      %DefaultImage{category: "restaurant", ...}

  """
  @spec for_categories([String.t()]) :: t() | nil
  def for_categories(categories) when is_list(categories) do
    categories
    |> Enum.find_value(&for_category/1)
  end

  @doc """
  Get all active default images.

  Returns all currently active default images, ordered by category name.
  """
  @spec list_active() :: [t()]
  def list_active do
    from(di in __MODULE__,
      where: di.is_active == true,
      order_by: di.category
    )
    |> Repo.all()
  end

  @doc """
  Get all available categories that have default images.

  Returns a list of category strings for which default images exist.
  """
  @spec available_categories() :: [String.t()]
  def available_categories do
    from(di in __MODULE__,
      where: di.is_active == true,
      select: di.category,
      order_by: di.category
    )
    |> Repo.all()
  end

  # Private validation functions

  defp validate_url(changeset, field, opts \\ []) do
    allow_nil = Keyword.get(opts, :allow_nil, false)

    validate_change(changeset, field, fn field, value ->
      cond do
        is_nil(value) and allow_nil ->
          []

        is_nil(value) and not allow_nil ->
          [{field, "can't be blank"}]

        not is_binary(value) ->
          [{field, "must be a string"}]

        not valid_url?(value) ->
          [{field, "must be a valid URL"}]

        true ->
          []
      end
    end)
  end

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    # Allow both full URLs and relative paths for fallback URLs
    cond do
      uri.scheme in ["http", "https"] and uri.host != nil -> true
      String.starts_with?(url, "/") -> true  # Allow relative paths
      true -> false
    end
  end

  defp valid_url?(_), do: false
end