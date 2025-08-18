defmodule RouteWiseApiWeb.ScrapingChannel do
  @moduledoc """
  Real-time WebSocket channel for scraping updates.
  Provides instant notifications when scraping completes.
  """
  
  use RouteWiseApiWeb, :channel
  require Logger

  @impl true
  def join("scraping:" <> user_id, _params, socket) do
    # Subscribe to user-specific scraping updates
    Phoenix.PubSub.subscribe(RouteWiseApi.PubSub, "user:#{user_id}")
    
    Logger.info("🔌 User #{user_id} joined scraping channel")
    {:ok, assign(socket, :user_id, user_id)}
  end

  # Handle location-specific subscriptions
  @impl true
  def join("location:" <> location_key, _params, socket) do
    Phoenix.PubSub.subscribe(RouteWiseApi.PubSub, "location:#{location_key}")
    
    Logger.info("🔌 Subscribed to location updates for #{location_key}")
    {:ok, assign(socket, :location, location_key)}
  end

  @impl true
  def handle_info({:scraping_update, event_type, data}, socket) do
    push(socket, "scraping_update", %{
      type: event_type,
      data: data,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_places_available, result}, socket) do
    push(socket, "places_ready", %{
      location: result.location,
      total_places: result.total_places,
      restaurants: result.restaurants_count,
      attractions: result.attractions_count,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    {:noreply, socket}
  end

  # Client can request scraping for a location
  @impl true
  def handle_in("request_scraping", %{"city" => city, "state" => state}, socket) do
    user_id = socket.assigns[:user_id]
    
    RouteWiseApi.BackgroundScraper.scrape_if_needed(city, state, user_id)
    
    push(socket, "scraping_requested", %{
      city: city,
      state: state,
      message: "Scraping request received"
    })
    
    {:noreply, socket}
  end

  @impl true
  def handle_in("get_status", %{"location" => location}, socket) do
    # Get current status of scraping job
    status = RouteWiseApi.BackgroundScraper.get_scrape_status(location)
    
    push(socket, "status_update", %{
      location: location,
      status: status
    })
    
    {:noreply, socket}
  end
end