defmodule RouteWiseApi.Blog do
  @moduledoc """
  The Blog context for managing blog posts.
  """

  import Ecto.Query, warn: false
  alias RouteWiseApi.Repo
  alias RouteWiseApi.Blog.Post

  @doc """
  Returns the list of published blog posts.
  """
  def list_published_posts do
    Post
    |> where([p], p.published == true)
    |> order_by([p], desc: p.published_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of all blog posts (for admin).
  """
  def list_posts do
    Post
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single published post by slug.
  """
  def get_published_post_by_slug(slug) do
    Post
    |> where([p], p.slug == ^slug and p.published == true)
    |> Repo.one()
  end

  @doc """
  Gets a single post by id.
  """
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Creates a blog post.
  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a blog post.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a blog post.
  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Publishes a blog post.
  """
  def publish_post(%Post{} = post) do
    post
    |> Post.changeset(%{published: true, published_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Unpublishes a blog post.
  """
  def unpublish_post(%Post{} = post) do
    post
    |> Post.changeset(%{published: false, published_at: nil})
    |> Repo.update()
  end
end