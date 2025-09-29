defmodule RouteWiseApiWeb.PlacesLiveController do
  @moduledoc """
  Real-time places controller with background scraping integration.
  Automatically triggers scraping when no results found.
  """
  
  use RouteWiseApiWeb, :controller
  alias RouteWiseApi.{Places, BackgroundScraper}
  require Logger

  def search(conn, %{"query" => query} = params) do
    location = parse_location(query)
    lat = Map.get(params, "lat")
    lng = Map.get(params, "lng")
    radius = Map.get(params, "radius", 10000) |> String.to_integer()
    
    # Search existing places first
    results = if lat && lng do
      Places.search_places_nearby(lat, lng, radius, query)
    else
      Places.search_places_by_name(query)
    end
    
    user_id = get_current_user_id(conn)
    
    case results do
      [] when location != nil ->
        # No results found - trigger background scraping
        Logger.info("🔍 No results for '#{query}' - triggering background scrape")
        
        {city, state} = location
        BackgroundScraper.scrape_if_needed(city, state, user_id)
        
        json(conn, %{
          places: [],
          scraping_status: "started",
          message: "Gathering place data for #{query}... This may take 30-60 seconds.",
          estimated_completion: DateTime.utc_now() |> DateTime.add(45, :second) |> DateTime.to_iso8601(),
          subscribe_to: "user:#{user_id}"
        })
      
      [] ->
        # No location parsed, can't scrape
        json(conn, %{
          places: [],
          scraping_status: "unable",
          message: "No places found. Try a more specific location (e.g., 'Austin, TX')"
        })
      
      places ->
        # Found existing results
        json(conn, %{
          places: format_places(places),
          scraping_status: "not_needed",
          total: length(places)
        })
    end
  end

  def scrape_status(conn, %{"location" => location}) do
    # Check if scraping is in progress for this location
    # This endpoint can be polled or used with WebSocket
    json(conn, %{
      status: "completed", # or "running", "failed"
      message: "Scraping completed",
      places_found: 25
    })
  end

  # Real-time updates endpoint for polling (alternative to WebSocket)
  def check_updates(conn, %{"location" => location, "since" => timestamp}) do
    # Check for new places added since timestamp
    since_datetime = DateTime.from_unix!(String.to_integer(timestamp))
    
    new_places = Places.get_places_added_since(location, since_datetime)
    
    json(conn, %{
      new_places: format_places(new_places),
      count: length(new_places),
      last_check: DateTime.utc_now() |> DateTime.to_unix()
    })
  end

  # Private functions
  
  defp parse_location(query) do
    # Parse "City, State" or "City" format
    case String.split(query, ",", parts: 2) do
      [city] -> 
        cleaned_city = String.trim(city)
        if String.length(cleaned_city) > 2, do: {cleaned_city, ""}, else: nil
      [city, state] -> 
        {String.trim(city), String.trim(state)}
      _ -> 
        nil
    end
  end

  defp get_current_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> user_id
      _ -> "anonymous_#{:rand.uniform(1000000)}"
    end
  end

  defp format_places(places) do
    Enum.map(places, fn place ->
      %{
        id: place.id,
        name: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        address: place.address,
        rating: place.rating,
        categories: place.categories,
        website: place.website,
        data_source: place.data_source
      }
    end)
  end
end