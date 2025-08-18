defmodule RouteWiseApiWeb.BlogJSON do
  @moduledoc """
  JSON rendering for blog posts.
  """

  alias RouteWiseApi.Blog.Post

  @doc """
  Renders a list of blog posts.
  """
  def index(%{posts: posts}) do
    %{data: for(post <- posts, do: data(post))}
  end

  @doc """
  Renders a single blog post.
  """
  def show(%{post: post}) do
    %{data: data(post)}
  end

  defp data(%Post{} = post) do
    %{
      id: post.id,
      title: post.title,
      slug: post.slug,
      content: post.content,
      excerpt: post.excerpt,
      featured_image: post.featured_image,
      author: post.author,
      published: post.published,
      published_at: post.published_at,
      meta_description: post.meta_description,
      tags: post.tags,
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end
end