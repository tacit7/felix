defmodule RouteWiseApiWeb.InterestsController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Trips

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  GET /api/interests/categories - List all interest categories
  """
  def categories(conn, _params) do
    categories = Trips.list_interest_categories()
    render(conn, :categories, categories: categories)
  end

  @doc """
  GET /api/interests - List user's interests
  """
  def index(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_interests = Trips.list_user_interests(current_user.id)
    render(conn, :index, user_interests: user_interests)
  end

  @doc """
  POST /api/interests - Create user interests from category names
  """
  def create(conn, %{"categories" => category_names, "priority" => priority}) when is_list(category_names) do
    current_user = Guardian.Plug.current_resource(conn)
    
    with {:ok, user_interests} <- Trips.create_user_interests_from_names(category_names, current_user.id, priority) do
      conn
      |> put_status(:created)
      |> render(:index, user_interests: user_interests)
    else
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: RouteWiseApiWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def create(conn, %{"categories" => category_names}) when is_list(category_names) do
    create(conn, %{"categories" => category_names, "priority" => 1})
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "categories must be a list of category names"})
  end

  @doc """
  PUT /api/interests/:id - Update a user interest
  """
  def update(conn, %{"id" => id, "interest" => interest_params}) do
    current_user = Guardian.Plug.current_resource(conn)
    
    # First verify the user interest belongs to the current user
    case Trips.get_user_interest!(id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json(%{error: "Interest not found"})
      user_interest ->
        if user_interest.user_id == current_user.id do
          with {:ok, user_interest} <- Trips.update_user_interest(user_interest, interest_params) do
            render(conn, :show, user_interest: user_interest)
          else
            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> put_view(json: RouteWiseApiWeb.ChangesetJSON)
              |> render(:error, changeset: changeset)
          end
        else
          conn
          |> put_status(:not_found)
          |> json(%{error: "Interest not found"})
        end
    end
  end

  @doc """
  DELETE /api/interests/:id - Delete a user interest
  """
  def delete(conn, %{"id" => id}) do
    current_user = Guardian.Plug.current_resource(conn)
    
    case Trips.get_user_interest!(id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json(%{error: "Interest not found"})
      user_interest ->
        if user_interest.user_id == current_user.id do
          with {:ok, _user_interest} <- Trips.delete_user_interest(user_interest) do
            send_resp(conn, :no_content, "")
          else
            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> put_view(json: RouteWiseApiWeb.ChangesetJSON)
              |> render(:error, changeset: changeset)
          end
        else
          conn
          |> put_status(:not_found)
          |> json(%{error: "Interest not found"})
        end
    end
  end
end