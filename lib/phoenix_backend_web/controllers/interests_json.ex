defmodule RouteWiseApiWeb.InterestsJSON do
  import RouteWiseApiWeb.CacheHelpers
  alias RouteWiseApi.Trips.{InterestCategory, UserInterest}

  @doc """
  Renders a list of interest categories.
  """
  def categories(%{categories: categories} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: for(category <- categories, do: category_data(category))}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders a list of user interests.
  """
  def index(%{user_interests: user_interests} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: for(user_interest <- user_interests, do: user_interest_data(user_interest))}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders a single user interest.
  """
  def show(%{user_interest: user_interest} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: user_interest_data(user_interest)}
    |> maybe_add_cache_meta(cache_info)
  end

  defp category_data(%InterestCategory{} = category) do
    %{
      id: category.id,
      name: category.name,
      display_name: category.display_name,
      description: category.description,
      icon_name: category.icon_name,
      is_active: category.is_active
    }
  end

  defp user_interest_data(%UserInterest{} = user_interest) do
    base_data = %{
      id: user_interest.id,
      user_id: user_interest.user_id,
      category_id: user_interest.category_id,
      is_enabled: user_interest.is_enabled,
      priority: user_interest.priority,
      inserted_at: user_interest.inserted_at,
      updated_at: user_interest.updated_at
    }

    # Include category data if it's preloaded
    case user_interest do
      %{category: %InterestCategory{} = category} ->
        Map.put(base_data, :category, category_data(category))
      _ ->
        base_data
    end
  end
end