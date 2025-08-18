defmodule RouteWiseApi.LocationIQ.Monitoring do
  @moduledoc """
  Monitoring and metrics for LocationIQ API protection systems.
  
  Provides comprehensive observability for rate limiting, circuit breaker,
  and API usage patterns. Integrates with Phoenix telemetry for monitoring
  dashboards and alerting systems.
  
  Features:
  - API usage tracking and quotas
  - Rate limit violations and patterns  
  - Circuit breaker state changes and recovery
  - Cost tracking and budget alerts
  - Performance metrics and SLA monitoring
  """
  
  alias RouteWiseApi.LocationIQ.{RateLimiter, CircuitBreaker}
  require Logger

  @doc """
  Get comprehensive monitoring dashboard data.
  
  Returns current status, metrics, and health indicators for
  all LocationIQ protection systems.
  
  ## Examples
      iex> get_dashboard()
      %{
        api_health: :healthy,
        rate_limits: %{...},
        circuit_breaker: %{...},
        usage_stats: %{...},
        cost_tracking: %{...}
      }
  """
  def get_dashboard(user_id \\ "global") do
    %{
      timestamp: DateTime.utc_now(),
      api_health: get_api_health(),
      rate_limits: get_rate_limit_status(user_id),
      circuit_breaker: get_circuit_breaker_status(),
      usage_stats: get_usage_statistics(),
      cost_tracking: get_cost_estimates(),
      performance_metrics: get_performance_metrics()
    }
  end

  @doc """
  Check overall API health status.
  
  Returns health status based on circuit breaker state,
  rate limit usage, and recent error patterns.
  """
  def get_api_health() do
    circuit_state = CircuitBreaker.get_state("autocomplete")
    rate_status = RateLimiter.get_status("autocomplete")
    
    cond do
      circuit_state.status == :open ->
        :unhealthy
      
      circuit_state.status == :half_open ->
        :degraded
      
      circuit_state.failure_count >= 3 ->
        :warning
      
      is_rate_limited?(rate_status) ->
        :rate_limited
      
      true ->
        :healthy
    end
  end

  @doc """
  Record API usage metrics for telemetry.
  
  Emits telemetry events that can be consumed by monitoring
  systems, dashboards, and alerting tools.
  """
  def record_api_call(service, result, duration_ms, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "global")
    query = Keyword.get(opts, :query, "unknown")
    
    metadata = %{
      service: service,
      result: result,
      user_id: user_id,
      query: query,
      duration_ms: duration_ms
    }
    
    measurements = %{
      duration: duration_ms,
      count: 1
    }
    
    # Emit telemetry event
    :telemetry.execute([:location_iq, :api_call], measurements, metadata)
    
    # Log significant events
    case result do
      :success ->
        Logger.debug("LocationIQ API call succeeded in #{duration_ms}ms")
      
      :rate_limited ->
        Logger.warning("LocationIQ API call rate limited for #{user_id}")
        
      :circuit_open ->
        Logger.error("LocationIQ API call blocked by circuit breaker")
        
      {:error, reason} ->
        Logger.error("LocationIQ API call failed: #{inspect(reason)}")
    end
  end

  @doc """
  Record circuit breaker state changes for monitoring.
  """
  def record_circuit_state_change(service, old_state, new_state, reason \\ nil) do
    metadata = %{
      service: service,
      old_state: old_state,
      new_state: new_state,
      reason: reason
    }
    
    :telemetry.execute([:location_iq, :circuit_breaker, :state_change], %{count: 1}, metadata)
    
    Logger.info("LocationIQ circuit breaker #{service}: #{old_state} -> #{new_state}")
  end

  @doc """
  Get rate limiting status and patterns.
  """
  def get_rate_limit_status(user_id \\ "global") do
    status = RateLimiter.get_status("autocomplete", user_id)
    
    %{
      user_id: user_id,
      current_status: status,
      utilization: calculate_utilization(status),
      projected_exhaustion: calculate_exhaustion_time(status),
      recommendations: get_rate_limit_recommendations(status)
    }
  end

  @doc """
  Get circuit breaker status and health indicators.
  """
  def get_circuit_breaker_status() do
    state = CircuitBreaker.get_state("autocomplete")
    
    %{
      current_state: state,
      health_score: calculate_health_score(state),
      recovery_estimate: calculate_recovery_time(state),
      failure_patterns: analyze_failure_patterns(state),
      recommendations: get_circuit_breaker_recommendations(state)
    }
  end

  @doc """
  Get usage statistics for cost and capacity planning.
  """
  def get_usage_statistics() do
    # In a real implementation, you'd query stored metrics
    # For now, return sample structure
    %{
      daily_requests: get_daily_request_count(),
      hourly_patterns: get_hourly_usage_patterns(),
      top_queries: get_popular_queries(),
      user_distribution: get_user_request_distribution(),
      cache_hit_rate: get_cache_effectiveness()
    }
  end

  @doc """
  Estimate API costs based on current usage patterns.
  """
  def get_cost_estimates() do
    usage = get_usage_statistics()
    
    # LocationIQ pricing (example rates)
    cost_per_request = 0.004  # $0.004 per request after free tier
    free_tier_limit = 5000    # 5K requests per day free
    
    daily_requests = usage.daily_requests
    billable_requests = max(0, daily_requests - free_tier_limit)
    
    %{
      daily_requests: daily_requests,
      free_tier_usage: min(daily_requests, free_tier_limit),
      billable_requests: billable_requests,
      estimated_daily_cost: billable_requests * cost_per_request,
      estimated_monthly_cost: billable_requests * cost_per_request * 30,
      budget_alerts: get_budget_alerts(billable_requests * cost_per_request)
    }
  end

  @doc """
  Get performance metrics and SLA compliance.
  """
  def get_performance_metrics() do
    %{
      average_response_time: get_average_response_time(),
      p95_response_time: get_p95_response_time(),
      success_rate: get_success_rate(),
      availability: get_availability_percentage(),
      cache_hit_rate: get_cache_hit_rate(),
      sla_compliance: get_sla_compliance()
    }
  end

  # Private helper functions

  defp is_rate_limited?(rate_status) do
    Enum.any?(rate_status, fn {_window, stats} ->
      stats.tokens == 0
    end)
  end

  defp calculate_utilization(rate_status) do
    rate_status
    |> Enum.map(fn {window, stats} ->
      utilization = (stats.capacity - stats.tokens) / stats.capacity * 100
      {window, Float.round(utilization, 1)}
    end)
    |> Enum.into(%{})
  end

  defp calculate_exhaustion_time(rate_status) do
    # Calculate when rate limits will be exhausted at current usage
    rate_status
    |> Enum.map(fn {window, stats} ->
      if stats.tokens > 0 do
        {window, :not_exhausted}
      else
        {window, stats.next_refill}
      end
    end)
    |> Enum.into(%{})
  end

  defp get_rate_limit_recommendations(status) do
    recommendations = []
    
    # Check for high utilization
    high_util_windows = status
    |> Enum.filter(fn {_window, stats} ->
      utilization = (stats.capacity - stats.tokens) / stats.capacity
      utilization > 0.8
    end)
    
    recommendations = if length(high_util_windows) > 0 do
      ["Consider implementing user-specific rate limiting"] ++ recommendations
    else
      recommendations
    end
    
    # Check for frequent exhaustion
    exhausted_windows = status
    |> Enum.filter(fn {_window, stats} -> stats.tokens == 0 end)
    
    recommendations = if length(exhausted_windows) > 0 do
      ["Implement request queuing or backoff strategies"] ++ recommendations
    else
      recommendations
    end
    
    recommendations
  end

  defp calculate_health_score(circuit_state) do
    case circuit_state.status do
      :closed -> 
        # Health decreases with failure count
        max(0, 100 - (circuit_state.failure_count * 10))
      
      :half_open ->
        # Moderate health during recovery
        50
      
      :open ->
        # Low health when circuit is open
        10
    end
  end

  defp calculate_recovery_time(circuit_state) do
    case circuit_state.status do
      :open ->
        # Time until circuit tries half-open
        now = DateTime.utc_now()
        recovery_time = DateTime.add(circuit_state.state_changed_at, 30, :second)
        max(0, DateTime.diff(recovery_time, now, :second))
      
      :half_open ->
        "Testing recovery"
      
      :closed ->
        "Operational"
    end
  end

  defp analyze_failure_patterns(_circuit_state) do
    # In a real implementation, analyze historical failure data
    %{
      most_common_errors: ["Request timeout", "Service unavailable"],
      failure_frequency: "Low",
      recovery_success_rate: "85%"
    }
  end

  defp get_circuit_breaker_recommendations(circuit_state) do
    case circuit_state.status do
      :open ->
        ["Check LocationIQ service status", "Verify network connectivity"]
      
      :half_open ->
        ["Monitor recovery progress", "Be prepared for potential fallback"]
      
      :closed when circuit_state.failure_count > 2 ->
        ["Investigate recent error patterns", "Consider caching strategies"]
      
      _ ->
        ["System operating normally"]
    end
  end

  # Mock functions for demonstration (replace with real metrics)
  defp get_daily_request_count(), do: 1247
  defp get_hourly_usage_patterns(), do: %{peak_hour: 14, peak_requests: 89}
  defp get_popular_queries(), do: ["san francisco", "new york", "los angeles"]
  defp get_user_request_distribution(), do: %{anonymous: 60, authenticated: 40}
  defp get_cache_effectiveness(), do: 73.5
  defp get_average_response_time(), do: 245.7
  defp get_p95_response_time(), do: 892.1
  defp get_success_rate(), do: 98.2
  defp get_availability_percentage(), do: 99.5
  defp get_cache_hit_rate(), do: 73.5
  defp get_sla_compliance(), do: %{availability: :met, performance: :met}

  defp get_budget_alerts(daily_cost) do
    alerts = []
    
    alerts = if daily_cost > 5.0 do
      ["Daily cost exceeding $5.00"] ++ alerts
    else
      alerts
    end
    
    alerts = if daily_cost > 1.0 do
      ["Approaching daily budget limit"] ++ alerts
    else
      alerts
    end
    
    alerts
  end
end