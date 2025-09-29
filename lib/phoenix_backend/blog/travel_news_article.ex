defmodule RouteWiseApi.Blog.TravelNewsArticle do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, only: [:id, :title, :link, :description, :source, :subjects, :image, :published_at, :generated_at, :inserted_at, :updated_at]}

  schema "travel_news_articles" do
    field :title, :string
    field :link, :string
    field :description, :string
    field :source, :string
    field :subjects, {:array, :string}
    field :image, :string
    field :published_at, :utc_datetime
    field :generated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(travel_news_article, attrs) do
    travel_news_article
    |> cast(attrs, [:title, :link, :description, :source, :subjects, :image, :published_at, :generated_at])
    |> validate_required([:title, :link, :source, :published_at, :generated_at])
    |> validate_length(:title, max: 500)
    |> validate_length(:source, max: 100)
    |> validate_format(:link, ~r/^https?:\/\//, message: "must be a valid URL")
    |> unique_constraint(:link)
  end

  @doc """
  Creates a changeset from JSON article data
  """
  def from_json_changeset(attrs) when is_map(attrs) do
    # Convert camelCase keys to snake_case and parse datetime strings
    parsed_attrs =
      attrs
      |> normalize_keys()
      |> parse_datetime(:published_at)
      |> parse_datetime(:generated_at)

    %__MODULE__{}
    |> changeset(parsed_attrs)
  end

  defp normalize_keys(attrs) do
    # Convert publishedAt to published_at
    attrs
    |> Map.put(:published_at, Map.get(attrs, :publishedAt) || Map.get(attrs, "publishedAt"))
    |> Map.delete(:publishedAt)
    |> Map.delete("publishedAt")
  end

  defp parse_datetime(attrs, field) do
    case Map.get(attrs, field) do
      datetime_string when is_binary(datetime_string) ->
        case DateTime.from_iso8601(datetime_string) do
          {:ok, datetime, _offset} -> Map.put(attrs, field, datetime)
          _ -> attrs
        end
      _ -> attrs
    end
  end
end