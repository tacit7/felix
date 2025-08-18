defmodule RouteWiseApi.Caching.Interests do
  @moduledoc """
  Interest categories and user interests caching.
  """

  alias RouteWiseApi.Caching.Config

  @doc """
  Get cached interest categories.
  """
  def get_categories_cache do
    backend = Config.backend()
    backend.get("interests:categories")
  end

  @doc """
  Cache interest categories (rarely change, long TTL).
  """
  def put_categories_cache(categories) do
    # 24 hours for categories
    ttl = Config.ttl(:daily)
    backend = Config.backend()

    backend.put("interests:categories", categories, ttl)
  end
end
