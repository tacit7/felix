defmodule RouteWiseApi.Caching.Config do
  @moduledoc """
  Environment-aware cache configuration management.

  Handles backend selection, TTL policies, and supervision strategies
  based on Mix environment and application configuration.
  """

  require Logger

  @doc """
  Get the cache backend module for the current environment.
  Returns the configured backend or falls back to environment default.
  """
  def backend do
    case Application.get_env(:phoenix_backend, RouteWiseApi.Caching)[:backend] do
      nil ->
        backend = default_backend()
        Logger.info("Using default cache backend: #{inspect(backend)}")
        backend

      configured_backend ->
        configured_backend
    end
  end

  @doc """
  Get TTL for a specific cache category with environment multiplier applied.
  Categories: :short, :medium, :long, :daily
  """
  def ttl(category) when category in [:short, :medium, :long, :daily] do
    base_ttl = get_base_ttl(category)
    multiplier = ttl_multiplier()
    calculated_ttl = round(base_ttl * multiplier)

    if debug_enabled?() do
      Logger.debug(
        "Cache TTL calculated: #{category} = #{calculated_ttl}ms (base: #{base_ttl}ms, multiplier: #{multiplier})"
      )
    end

    calculated_ttl
  end

  @doc """
  Get TTL in seconds for external cache systems (Redis).
  """
  def ttl_seconds(category), do: div(ttl(category), 1000)

  @doc """
  Check if debug logging is enabled for cache operations.
  """
  def debug_enabled? do
    Application.get_env(:phoenix_backend, RouteWiseApi.Caching)[:enable_logging] || false
  end

  @doc """
  Check if metrics collection is enabled.
  """
  def metrics_enabled? do
    Application.get_env(:phoenix_backend, RouteWiseApi.Caching)[:enable_metrics] || false
  end

  @doc """
  Get Redis configuration with proper OTP supervision settings.
  """
  def redis_config do
    base_config = %{
      pool_size: get_redis_pool_size(),
      backoff_type: :exponential,
      backoff_initial: 1_000,
      backoff_max: 30_000
    }

    case get_redis_url() do
      nil ->
        nil

      url when is_binary(url) ->
        Map.put(base_config, :url, url)
    end
  end

  @doc """
  Get supervision strategy for cache backends.
  Development: :one_for_one (faster restart)
  Production: :rest_for_one (coordinated restart)
  """
  def supervision_strategy do
    case Mix.env() do
      :prod -> :rest_for_one
      _ -> :one_for_one
    end
  end

  @doc """
  Get cache invalidation strategy configuration.
  """
  def invalidation_config do
    %{
      # Use Phoenix.PubSub for distributed invalidation
      pubsub_server: RouteWiseApi.PubSub,
      invalidation_topic: "cache_invalidation",
      # Enable distributed invalidation in production
      distributed: Mix.env() == :prod
    }
  end

  @doc """
  Get environment-specific cache warming configuration.
  """
  def cache_warming_config do
    %{
      enabled: Mix.env() == :prod,
      # 5 minutes
      interval: 300_000,
      strategies: [:popular_routes, :public_trips, :interest_categories]
    }
  end

  # Private functions

  defp default_backend do
    case Mix.env() do
      :prod -> RouteWiseApi.Caching.Backend.Hybrid
      :test -> RouteWiseApi.Caching.Backend.Memory
      _ -> RouteWiseApi.Caching.Backend.Memory
    end
  end

  defp get_base_ttl(category) do
    default_ttls = %{
      # 5 minutes
      short: 300_000,
      # 15 minutes
      medium: 900_000,
      # 1 hour
      long: 3_600_000,
      # 24 hours
      daily: 86_400_000
    }

    ttls = Application.get_env(:phoenix_backend, RouteWiseApi.Caching)[:default_ttl] || %{}

    Map.get(ttls, category) || Map.get(default_ttls, category, 900_000)
  end

  defp ttl_multiplier do
    Application.get_env(:phoenix_backend, RouteWiseApi.Caching)[:ttl_multiplier] || 1.0
  end

  defp get_redis_url do
    case Application.get_env(:phoenix_backend, RouteWiseApi.Caching)[:redis_url] do
      nil ->
        System.get_env("REDIS_URL")

      {:system, env_var} ->
        System.get_env(env_var)

      url when is_binary(url) ->
        url
    end
  end

  defp get_redis_pool_size do
    Application.get_env(:phoenix_backend, RouteWiseApi.Caching)[:redis_pool_size] || 10
  end
end
