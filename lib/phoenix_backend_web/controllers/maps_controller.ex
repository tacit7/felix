defmodule RouteWiseApiWeb.MapsController do
  use RouteWiseApiWeb, :controller

  @doc """
  GET /api/maps-key - Return Google Maps API key for frontend
  """
  def get_api_key(conn, _params) do
    # Use Google Places API key for Maps (they're often the same key)
    maps_key = Application.get_env(:phoenix_backend, :google_places_api_key) || 
               System.get_env("GOOGLE_MAPS_API_KEY") || ""
    
    json(conn, %{apiKey: maps_key})
  end
end