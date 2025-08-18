defmodule RouteWiseApi.RouteService do
  @moduledoc """
  Service layer for route calculations and trip planning using LocationIQ.
  """

  alias RouteWiseApi.LocationIQ
  alias RouteWiseApi.Trips
  alias RouteWiseApi.Trips.Trip
  
  require Logger

  @doc """
  Calculate route for a trip and update trip's route_data.
  """
  def calculate_trip_route(%Trip{} = trip, options \\ %{}) do
    case calculate_route_from_trip_data(trip, options) do
      {:ok, route_data} ->
        update_trip_route_data(trip, route_data)
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calculate route from trip wizard data without saving to database.
  """
  def calculate_route_from_wizard_data(wizard_data, options \\ %{}) do
    with {:ok, origin} <- extract_origin(wizard_data),
         {:ok, destination} <- extract_destination(wizard_data),
         waypoints <- extract_waypoints(wizard_data) do
      
      calculate_route_with_locationiq(origin, destination, waypoints, options)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculate and optimize route with waypoints.
  """
  def calculate_optimized_route(origin, destination, waypoints, options \\ %{}) do
    calculate_route_with_locationiq(origin, destination, waypoints, options)
  end

  @doc """
  Get multiple route alternatives between two points.
  """
  def get_route_alternatives(origin, destination, options \\ %{}) do
    options = Map.put(options, :alternatives, 2)
    calculate_route_with_locationiq(origin, destination, [], options)
  end

  @doc """
  Calculate route distance and duration only (faster, less data).
  """
  def calculate_route_summary(origin, destination, waypoints \\ [], options \\ %{}) do
    case calculate_route_with_locationiq(origin, destination, waypoints, options) do
      {:ok, route_data} ->
        summary = %{
          distance: format_distance(route_data.distance),
          duration: format_duration(route_data.duration),
          distance_km: route_data.distance,
          duration_seconds: route_data.duration,
          polyline: route_data.polyline,
          steps: route_data.steps,
          estimated: route_data.estimated
        }
        {:ok, summary}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Estimate travel time based on departure time and traffic conditions.
  """
  def estimate_travel_time(origin, destination, departure_time, options \\ %{}) do
    options = 
      options
      |> Map.put(:departure_time, departure_time)
      |> Map.put(:traffic_model, "best_guess")
    
    calculate_route_summary(origin, destination, [], options)
  end

  # Private functions - LocationIQ Integration

  defp calculate_route_with_locationiq(origin, destination, waypoints, options) do
    Logger.info("Calculating route with LocationIQ: #{origin} -> #{destination}")
    
    with {:ok, start_coords} <- get_coordinates(origin),
         {:ok, end_coords} <- get_coordinates(destination),
         waypoint_coords <- get_waypoint_coordinates(waypoints) do
      
      routing_options = build_routing_options(options, waypoint_coords)
      
      case LocationIQ.get_directions(start_coords, end_coords, routing_options) do
        {:ok, route} ->
          formatted_route = format_locationiq_route(route, origin, destination)
          Logger.info("Route calculation successful: #{formatted_route.distance}km in #{formatted_route.duration}s")
          {:ok, formatted_route}
        
        {:error, reason, fallback_route} ->
          Logger.warning("LocationIQ routing failed: #{reason}, using fallback route")
          formatted_route = format_locationiq_route(fallback_route, origin, destination)
          {:ok, formatted_route}
        
        {:error, reason} ->
          Logger.error("LocationIQ routing failed: #{reason}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to get coordinates for routing: #{reason}")
        {:error, reason}
    end
  end

  defp get_coordinates(location) when is_binary(location) do
    case LocationIQ.geocode(location, limit: 1) do
      {:ok, [location_data | _]} ->
        {:ok, %{lat: location_data.lat, lng: location_data.lon}}
      
      {:ok, []} ->
        {:error, "No coordinates found for location: #{location}"}
      
      {:error, reason, fallback_data} when is_list(fallback_data) and length(fallback_data) > 0 ->
        # Use fallback data if available
        location_data = List.first(fallback_data)
        {:ok, %{lat: location_data.lat, lng: location_data.lon}}
        
      {:error, reason} ->
        {:error, "Geocoding failed for #{location}: #{inspect(reason)}"}
    end
  end

  defp get_coordinates(%{lat: lat, lng: lng}) when is_number(lat) and is_number(lng) do
    {:ok, %{lat: lat, lng: lng}}
  end

  defp get_coordinates(_), do: {:error, "Invalid location format"}

  defp get_waypoint_coordinates([]), do: []
  defp get_waypoint_coordinates(waypoints) when is_list(waypoints) do
    waypoints
    |> Enum.map(&get_coordinates/1)
    |> Enum.reduce([], fn
      {:ok, coords}, acc -> [coords | acc]
      {:error, _}, acc -> acc
    end)
    |> Enum.reverse()
  end

  defp build_routing_options(options, waypoint_coords) do
    base_options = [
      steps: Map.get(options, :include_steps, true),
      alternatives: Map.get(options, :alternatives, 0),
      profile: Map.get(options, :profile, "driving")
    ]
    
    if Enum.empty?(waypoint_coords) do
      base_options
    else
      Keyword.put(base_options, :waypoints, waypoint_coords)
    end
  end

  defp format_locationiq_route(route, origin, destination) do
    %{
      distance: format_distance(route.distance),
      duration: format_duration(route.duration),
      distance_km: route.distance,
      duration_seconds: route.duration,
      start_address: origin,
      end_address: destination,
      polyline: route.polyline,
      steps: route.steps || [],
      geometry: route.raw_geometry,
      estimated: Map.get(route, :estimated, false)
    }
  end

  defp format_distance(distance_km) when is_number(distance_km) do
    cond do
      distance_km >= 1.0 -> 
        "#{:erlang.float_to_binary(distance_km, decimals: 1)} km"
      true -> 
        "#{round(distance_km * 1000)} m"
    end
  end

  defp format_duration(duration_seconds) when is_number(duration_seconds) do
    cond do
      duration_seconds >= 3600 ->
        hours = div(duration_seconds, 3600)
        minutes = div(rem(duration_seconds, 3600), 60)
        "#{hours} hour#{if hours > 1, do: "s", else: ""} #{minutes} min#{if minutes != 1, do: "s", else: ""}"
      
      duration_seconds >= 60 ->
        minutes = div(duration_seconds, 60)
        "#{minutes} min#{if minutes != 1, do: "s", else: ""}"
      
      true ->
        "#{duration_seconds} second#{if duration_seconds != 1, do: "s", else: ""}"
    end
  end

  # Private functions - Trip Data Extraction

  defp calculate_route_from_trip_data(%Trip{} = trip, options) do
    with {:ok, origin} <- extract_trip_origin(trip),
         {:ok, destination} <- extract_trip_destination(trip),
         waypoints <- extract_trip_waypoints(trip) do
      
      calculate_route_with_locationiq(origin, destination, waypoints, options)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_trip_origin(%Trip{start_city: start_city}) when is_binary(start_city) and start_city != "" do
    {:ok, start_city}
  end
  defp extract_trip_origin(_), do: {:error, {:invalid_origin, "Trip must have a valid start_city"}}

  defp extract_trip_destination(%Trip{end_city: end_city}) when is_binary(end_city) and end_city != "" do
    {:ok, end_city}
  end
  defp extract_trip_destination(_), do: {:error, {:invalid_destination, "Trip must have a valid end_city"}}

  defp extract_trip_waypoints(%Trip{checkpoints: %{"stops" => stops}}) when is_list(stops) do
    stops
  end
  defp extract_trip_waypoints(%Trip{checkpoints: checkpoints}) when is_map(checkpoints) do
    Map.get(checkpoints, "stops", [])
  end
  defp extract_trip_waypoints(_), do: []

  defp extract_origin(%{"startLocation" => %{"description" => description}}) when is_binary(description) do
    {:ok, description}
  end
  defp extract_origin(%{"startLocation" => %{"main_text" => main_text}}) when is_binary(main_text) do
    {:ok, main_text}
  end
  defp extract_origin(_), do: {:error, {:invalid_origin, "Wizard data must have valid startLocation"}}

  defp extract_destination(%{"endLocation" => %{"description" => description}}) when is_binary(description) do
    {:ok, description}
  end
  defp extract_destination(%{"endLocation" => %{"main_text" => main_text}}) when is_binary(main_text) do
    {:ok, main_text}
  end
  defp extract_destination(_), do: {:error, {:invalid_destination, "Wizard data must have valid endLocation"}}

  defp extract_waypoints(%{"stops" => stops}) when is_list(stops) do
    Enum.map(stops, fn stop ->
      cond do
        is_binary(stop) -> stop
        is_map(stop) -> 
          stop["description"] || stop["main_text"] || ""
        true -> ""
      end
    end)
    |> Enum.filter(&(&1 != ""))
  end
  defp extract_waypoints(_), do: []

  defp update_trip_route_data(%Trip{} = trip, route_data) do
    case Trips.update_trip(trip, %{route_data: route_data}) do
      {:ok, updated_trip} -> {:ok, updated_trip}
      {:error, changeset} -> {:error, {:update_failed, changeset}}
    end
  end

  defp extract_route_summary(route_data) do
    %{
      distance: route_data.distance,
      duration: route_data.duration,
      start_address: route_data.start_address,
      end_address: route_data.end_address
    }
  end

  @doc """
  Calculate estimated costs for a trip based on route data.
  """
  def estimate_trip_costs(route_data, options \\ %{}) do
    distance_km = parse_distance_to_km(route_data.distance)
    
    costs = %{
      fuel: calculate_fuel_cost(distance_km, options),
      tolls: estimate_toll_costs(route_data, options),
      parking: estimate_parking_costs(route_data, options)
    }
    
    total = costs.fuel + costs.tolls + costs.parking
    
    Map.put(costs, :total, total)
  end

  defp parse_distance_to_km(distance_text) do
    # Parse "123 km" or "45.6 mi" to kilometers
    cond do
      String.contains?(distance_text, "km") ->
        distance_text
        |> String.replace(~r/[^\d.]/, "")
        |> String.to_float()
      
      String.contains?(distance_text, "mi") ->
        distance_text
        |> String.replace(~r/[^\d.]/, "")
        |> String.to_float()
        |> Kernel.*(1.60934) # Convert miles to km
      
      true -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp calculate_fuel_cost(distance_km, options) do
    fuel_efficiency = Map.get(options, :fuel_efficiency, 8.0) # L/100km
    fuel_price = Map.get(options, :fuel_price, 1.50) # per liter
    
    (distance_km / 100.0) * fuel_efficiency * fuel_price
  end

  defp estimate_toll_costs(_route_data, options) do
    # Simplified toll estimation - in production, integrate with toll APIs
    Map.get(options, :estimated_tolls, 0.0)
  end

  defp estimate_parking_costs(_route_data, options) do
    # Simplified parking estimation
    Map.get(options, :estimated_parking, 0.0)
  end

end