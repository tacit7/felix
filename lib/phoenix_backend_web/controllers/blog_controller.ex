defmodule RouteWiseApiWeb.BlogController do
  @moduledoc """
  Controller for blog functionality.
  """

  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Blog
  alias RouteWiseApi.Blog.Post

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  List all published blog posts.
  """
  def index(conn, _params) do
    posts = Blog.list_published_posts()
    render(conn, :index, posts: posts)
  end

  @doc """
  Get a single published blog post by slug.
  """
  def show(conn, %{"slug" => slug}) do
    case Blog.get_published_post_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Blog post not found"})
      post ->
        render(conn, :show, post: post)
    end
  end

  @doc """
  Create a new blog post (admin only for now).
  """
  def create(conn, %{"post" => post_params}) do
    case Blog.create_post(post_params) do
      {:ok, post} ->
        conn
        |> put_status(:created)
        |> render(:show, post: post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(RouteWiseApiWeb.ChangesetJSON, :error, changeset: changeset)
    end
  end

  @doc """
  Update a blog post (admin only for now).
  """
  def update(conn, %{"id" => id, "post" => post_params}) do
    post = Blog.get_post!(id)

    case Blog.update_post(post, post_params) do
      {:ok, post} ->
        render(conn, :show, post: post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(RouteWiseApiWeb.ChangesetJSON, :error, changeset: changeset)
    end
  end

  @doc """
  Delete a blog post (admin only for now).
  """
  def delete(conn, %{"id" => id}) do
    post = Blog.get_post!(id)

    with {:ok, %Post{}} <- Blog.delete_post(post) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Publish a blog post (admin only for now).
  """
  def publish(conn, %{"id" => id}) do
    post = Blog.get_post!(id)

    case Blog.publish_post(post) do
      {:ok, post} ->
        render(conn, :show, post: post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(RouteWiseApiWeb.ChangesetJSON, :error, changeset: changeset)
    end
  end
end