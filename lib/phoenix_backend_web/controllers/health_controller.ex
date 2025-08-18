defmodule RouteWiseApiWeb.HealthController do
  use RouteWiseApiWeb, :controller
  
  alias RouteWiseApi.GoogleAPITracker

  def check(conn, _params) do
    json(conn, %{
      status: "ok",
      message: "RouteWise API is running",
      timestamp: DateTime.utc_now(),
      version: "0.1.0"
    })
  end

  @doc """
  Check Google API usage for the current month.
  GET /api/health/google-api-usage
  """
  def google_api_usage(conn, _params) do
    monthly_usage = GoogleAPITracker.get_monthly_usage()
    daily_usage = GoogleAPITracker.get_daily_usage()
    breakdown = GoogleAPITracker.get_usage_breakdown()
    
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      google_api_usage: %{
        monthly: monthly_usage,
        daily: daily_usage,
        breakdown: breakdown,
        summary: GoogleAPITracker.usage_summary()
      }
    })
  end
end