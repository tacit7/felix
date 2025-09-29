defmodule RouteWiseApiWeb.TravelNewsController do
  use RouteWiseApiWeb, :controller

  import Ecto.Query
  alias RouteWiseApi.Repo
  alias RouteWiseApi.Blog.TravelNewsArticle

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  List all travel news articles with optional pagination and filters
  """
  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "10") |> String.to_integer()
    source = Map.get(params, "source")
    subject = Map.get(params, "subject")

    # Build query with filters
    query =
      TravelNewsArticle
      |> order_by([a], desc: a.published_at)
      |> maybe_filter_by_source(source)
      |> maybe_filter_by_subject(subject)

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Apply pagination
    offset = (page - 1) * per_page

    articles =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    # Calculate pagination metadata
    total_pages = ceil(total_count / per_page)
    has_next = page < total_pages
    has_prev = page > 1

    response = %{
      articles: articles,
      pagination: %{
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        has_next: has_next,
        has_prev: has_prev
      }
    }

    json(conn, response)
  end

  @doc """
  Get a single travel news article by ID
  """
  def show(conn, %{"id" => id}) do
    case Repo.get(TravelNewsArticle, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Article not found"})

      article ->
        json(conn, %{article: article})
    end
  end

  @doc """
  Get recent travel news articles (last 7 days)
  """
  def recent(conn, params) do
    limit = Map.get(params, "limit", "5") |> String.to_integer()
    days_back = Map.get(params, "days", "7") |> String.to_integer()

    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    articles =
      TravelNewsArticle
      |> where([a], a.published_at >= ^cutoff_date)
      |> order_by([a], desc: a.published_at)
      |> limit(^limit)
      |> Repo.all()

    json(conn, %{
      articles: articles,
      filters: %{
        days_back: days_back,
        cutoff_date: cutoff_date,
        count: length(articles)
      }
    })
  end

  @doc """
  Get travel news articles by subject/category
  """
  def by_subject(conn, %{"subject" => subject} = params) do
    limit = Map.get(params, "limit", "10") |> String.to_integer()

    articles =
      TravelNewsArticle
      |> where([a], ^subject in a.subjects)
      |> order_by([a], desc: a.published_at)
      |> limit(^limit)
      |> Repo.all()

    json(conn, %{
      articles: articles,
      subject: subject,
      count: length(articles)
    })
  end

  @doc """
  Get all available subjects/categories from articles
  """
  def subjects(conn, _params) do
    subjects =
      TravelNewsArticle
      |> select([a], a.subjects)
      |> Repo.all()
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    json(conn, %{subjects: subjects})
  end

  # Private helper functions

  defp maybe_filter_by_source(query, nil), do: query
  defp maybe_filter_by_source(query, source) do
    where(query, [a], ilike(a.source, ^"%#{source}%"))
  end

  defp maybe_filter_by_subject(query, nil), do: query
  defp maybe_filter_by_subject(query, subject) do
    where(query, [a], ^subject in a.subjects)
  end
end