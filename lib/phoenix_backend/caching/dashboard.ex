defmodule RouteWiseApi.Caching.Dashboard do
  @moduledoc """
  Dashboard-specific caching operations with user-aware TTL strategies.
  """

  alias RouteWiseApi.Caching.Config
  require Logger

  @doc """
  Get cached dashboard data for a user or anonymous user.
  """
  def get_cache(user_id \\ :anonymous) do
    cache_key = build_cache_key(user_id)
    backend = Config.backend()

    case backend.get(cache_key) do
      {:ok, data} ->
        if Config.debug_enabled?() do
          Logger.debug("Dashboard cache hit for #{inspect(user_id)}")
        end

        {:ok, data}

      :error ->
        if Config.debug_enabled?() do
          Logger.debug("Dashboard cache miss for #{inspect(user_id)}")
        end

        :error
    end
  end

  @doc """
  Cache dashboard data with appropriate TTL based on user type.
  """
  def put_cache(user_id \\ :anonymous, data) do
    cache_key = build_cache_key(user_id)
    ttl = get_dashboard_ttl(user_id)
    backend = Config.backend()

    case backend.put(cache_key, data, ttl) do
      :ok ->
        if Config.debug_enabled?() do
          Logger.debug("Dashboard data cached for #{inspect(user_id)} (TTL: #{ttl}ms)")
        end

        :ok

      error ->
        Logger.warning(
          "Failed to cache dashboard data for #{inspect(user_id)}: #{inspect(error)}"
        )

        error
    end
  end

  @doc """
  Invalidate cached dashboard data for a user.
  """
  def invalidate_cache(user_id \\ :anonymous) do
    cache_key = build_cache_key(user_id)
    backend = Config.backend()

    case backend.delete(cache_key) do
      :ok ->
        if Config.debug_enabled?() do
          Logger.debug("Dashboard cache invalidated for #{inspect(user_id)}")
        end

        :ok

      error ->
        Logger.warning(
          "Failed to invalidate dashboard cache for #{inspect(user_id)}: #{inspect(error)}"
        )

        error
    end
  end

  # Private functions

  defp build_cache_key(:anonymous), do: "dashboard:anonymous"
  defp build_cache_key(user_id), do: "dashboard:user:#{user_id}"

  defp get_dashboard_ttl(:anonymous) do
    # Anonymous users get longer TTL since data is more static
    Config.ttl(:long)
  end

  defp get_dashboard_ttl(_user_id) do
    # Authenticated users get medium TTL for personalized data
    Config.ttl(:medium)
  end
end
