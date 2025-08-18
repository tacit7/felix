defmodule RouteWiseApiWeb.MonitoringController do
  @moduledoc """
  API endpoint for backend integration monitoring and health checks.
  Provides detailed metrics about Express.js integration performance.
  """

  use RouteWiseApiWeb, :controller
  
  alias RouteWiseApi.Cache
  alias RouteWiseApi.Integrations.ExpressClient

  @doc """
  Get comprehensive integration health and performance metrics
  """
  def health(conn, _params) do
    metrics = %{
      phoenix: phoenix_health(),
      express_integration: express_health(),
      cache: cache_health(),
      database: database_health(),
      timestamp: DateTime.utc_now()
    }

    overall_status = determine_overall_status(metrics)

    response = %{
      success: true,
      status: overall_status,
      data: metrics,
      timestamp: DateTime.utc_now()
    }

    status_code = if overall_status == "healthy", do: :ok, else: :service_unavailable

    conn
    |> put_status(status_code)
    |> json(response)
  end

  @doc """
  Get detailed Express.js integration metrics
  """
  def express_metrics(conn, _params) do
    start_time = System.monotonic_time(:millisecond)

    # Test Express.js connectivity and response times
    health_check_result = measure_operation(fn -> ExpressClient.health_check() end)
    categories_result = measure_operation(fn -> ExpressClient.get_interest_categories() end)

    total_time = System.monotonic_time(:millisecond) - start_time

    metrics = %{
      health_check: health_check_result,
      categories_fetch: categories_result,
      total_test_time: total_time,
      cache_stats: Cache.stats(),
      connectivity: assess_connectivity([health_check_result, categories_result]),
      recommendations: generate_performance_recommendations([health_check_result, categories_result])
    }

    json(conn, %{
      success: true,
      data: metrics,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Get cache performance metrics
  """
  def cache_metrics(conn, _params) do
    stats = Cache.stats()
    
    cache_efficiency = case stats.total_keys do
      0 -> 0.0
      total -> (total - stats.expired_keys) / total * 100.0
    end

    metrics = %{
      cache_stats: stats,
      efficiency_percentage: Float.round(cache_efficiency, 2),
      recommendations: cache_recommendations(stats)
    }

    json(conn, %{
      success: true,
      data: metrics,
      timestamp: DateTime.utc_now()
    })
  end

  # Private helper functions

  defp phoenix_health do
    %{
      status: "healthy",
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      memory_usage: :erlang.memory(:total),
      process_count: length(Process.list())
    }
  end

  defp express_health do
    case measure_operation(fn -> ExpressClient.health_check() end) do
      %{success: true, duration: duration} ->
        status = if duration < 1000, do: "healthy", else: "slow"
        %{
          status: status,
          response_time_ms: duration,
          last_check: DateTime.utc_now()
        }
      %{success: false, error: error, duration: duration} ->
        %{
          status: "unhealthy",
          error: inspect(error),
          response_time_ms: duration,
          last_check: DateTime.utc_now()
        }
    end
  end

  defp cache_health do
    stats = Cache.stats()
    
    efficiency = case stats.total_keys do
      0 -> 100.0
      total -> (total - stats.expired_keys) / total * 100.0
    end

    status = cond do
      efficiency > 80 -> "healthy"
      efficiency > 50 -> "degraded"
      true -> "poor"
    end

    %{
      status: status,
      efficiency_percentage: Float.round(efficiency, 2),
      total_keys: stats.total_keys,
      expired_keys: stats.expired_keys,
      active_timers: stats.active_timers
    }
  end

  defp database_health do
    try do
      # Simple database connectivity check
      case Ecto.Adapters.SQL.query(RouteWiseApi.Repo, "SELECT 1", []) do
        {:ok, _} -> %{status: "healthy", connection: "active"}
        {:error, error} -> %{status: "unhealthy", error: inspect(error)}
      end
    rescue
      error -> %{status: "error", error: inspect(error)}
    end
  end

  defp determine_overall_status(metrics) do
    statuses = [
      metrics.phoenix.status,
      metrics.express_integration.status,
      metrics.cache.status,
      metrics.database.status
    ]

    cond do
      "unhealthy" in statuses or "error" in statuses -> "unhealthy"
      "degraded" in statuses or "slow" in statuses -> "degraded"
      true -> "healthy"
    end
  end

  defp measure_operation(operation) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      result = operation.()
      duration = System.monotonic_time(:millisecond) - start_time
      
      %{
        success: result == :ok or (is_tuple(result) and elem(result, 0) == :ok),
        result: sanitize_result(result),
        duration: duration
      }
    rescue
      error ->
        duration = System.monotonic_time(:millisecond) - start_time
        %{
          success: false,
          error: inspect(error),
          duration: duration
        }
    end
  end
  
  defp sanitize_result({:ok, data}), do: data
  defp sanitize_result({:error, reason}), do: %{error: inspect(reason)}
  defp sanitize_result(result), do: result

  defp assess_connectivity(results) do
    successful_results = Enum.count(results, & &1.success)
    total_results = length(results)
    
    success_rate = successful_results / total_results * 100.0
    avg_response_time = results
                      |> Enum.map(& &1.duration)
                      |> Enum.sum()
                      |> div(total_results)

    %{
      success_rate_percentage: Float.round(success_rate, 2),
      average_response_time_ms: avg_response_time,
      total_tests: total_results,
      successful_tests: successful_results
    }
  end

  defp generate_performance_recommendations(results) do
    avg_response_time = results
                      |> Enum.map(& &1.duration)
                      |> Enum.sum()
                      |> div(length(results))

    recommendations = []

    recommendations = if avg_response_time > 1000 do
      ["Consider increasing cache TTL for Express.js responses" | recommendations]
    else
      recommendations
    end

    recommendations = if Enum.any?(results, &(not &1.success)) do
      ["Implement circuit breaker pattern for Express.js integration" | recommendations]
    else
      recommendations
    end

    recommendations = if avg_response_time > 500 do
      ["Consider implementing request batching for Express.js calls" | recommendations]
    else
      recommendations
    end

    if recommendations == [] do
      ["Performance is optimal"]
    else
      recommendations
    end
  end

  defp cache_recommendations(stats) do
    recommendations = []

    recommendations = if stats.expired_keys > stats.total_keys * 0.3 do
      ["High expired key ratio - consider adjusting TTL values" | recommendations]
    else
      recommendations
    end

    recommendations = if stats.active_timers > 100 do
      ["High number of active timers - consider cache cleanup optimization" | recommendations]
    else
      recommendations
    end

    if recommendations == [] do
      ["Cache performance is optimal"]
    else
      recommendations
    end
  end
end