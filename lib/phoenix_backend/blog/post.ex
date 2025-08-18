defmodule RouteWiseApi.Blog.Post do
  @moduledoc """
  Blog post schema for RouteWise travel blog.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "blog_posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :featured_image, :string
    field :author, :string, default: "RouteWise Team"
    field :published, :boolean, default: false
    field :published_at, :utc_datetime
    field :meta_description, :string
    field :tags, {:array, :string}, default: []

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for blog post creation and updates.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :slug, :content, :excerpt, :featured_image, :author, :published, :published_at, :meta_description, :tags])
    |> validate_required([:title, :content])
    |> generate_slug_if_missing()
    |> validate_length(:title, min: 5, max: 200)
    |> validate_length(:excerpt, max: 500)
    |> validate_length(:meta_description, max: 160)
    |> unique_constraint(:slug)
    |> set_published_at()
  end

  defp generate_slug_if_missing(%Ecto.Changeset{changes: %{title: title}} = changeset) do
    case get_field(changeset, :slug) do
      nil ->
        slug = title
               |> String.downcase()
               |> String.replace(~r/[^a-z0-9\s-]/, "")
               |> String.replace(~r/\s+/, "-")
               |> String.trim("-")
        put_change(changeset, :slug, slug)
      _ ->
        changeset
    end
  end
  defp generate_slug_if_missing(changeset), do: changeset

  defp set_published_at(%Ecto.Changeset{changes: %{published: true}} = changeset) do
    case get_field(changeset, :published_at) do
      nil -> put_change(changeset, :published_at, DateTime.utc_now())
      _ -> changeset
    end
  end
  defp set_published_at(changeset), do: changeset
end