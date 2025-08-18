defmodule RouteWiseApiWeb.RoutesController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.RouteService
  alias RouteWiseApi.Trips

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  POST /api/routes/calculate - Calculate route between points
  """
  def calculate(conn, %{"origin" => origin, "destination" => destination} = params) do
    waypoints = Map.get(params, "waypoints", [])
    options = build_route_options(params)

    case RouteService.calculate_optimized_route(origin, destination, waypoints, options) do
      {:ok, route_data} ->
        # Routes are typically cached, check if this looks like cached data
        cache_info = determine_route_cache_status(route_data)
        render(conn, :route, route_data: route_data, cache_info: cache_info)
      
      {:error, reason} ->
        {:error, format_route_error(reason)}
    end
  end

  def calculate(_conn, _params) do
    {:error, {:bad_request, "origin and destination are required"}}
  end

  @doc """
  POST /api/routes/wizard - Calculate route from wizard data
  """
  def calculate_from_wizard(conn, %{"wizard_data" => wizard_data} = params) do
    options = build_route_options(params)

    case RouteService.calculate_route_from_wizard_data(wizard_data, options) do
      {:ok, route_data} ->
        render(conn, :route, route_data: route_data)
      
      {:error, reason} ->
        {:error, format_route_error(reason)}
    end
  end

  def calculate_from_wizard(_conn, _params) do
    {:error, {:bad_request, "wizard_data is required"}}
  end

  @doc """
  GET /api/routes/trip/:trip_id - Get route for existing trip
  """
  def get_trip_route(conn, %{"trip_id" => trip_id} = params) do
    current_user = Guardian.Plug.current_resource(conn)
    
    case Trips.get_user_trip(trip_id, current_user.id) do
      nil -> {:error, :not_found}
      trip ->
        # If trip already has route_data, return it
        if trip.route_data && map_size(trip.route_data) > 0 do
          render(conn, :route, route_data: trip.route_data)
        else
          # Calculate route and update trip
          options = build_route_options(params)
          
          case RouteService.calculate_trip_route(trip, options) do
            {:ok, updated_trip} ->
              render(conn, :route, route_data: updated_trip.route_data)
            
            {:error, reason} ->
              {:error, format_route_error(reason)}
          end
        end
    end
  end

  @doc """
  POST /api/routes/optimize - Optimize waypoint order
  """
  def optimize(conn, %{"origin" => origin, "destination" => destination, "waypoints" => waypoints} = params) do
    options = 
      params
      |> build_route_options()
      |> Map.put(:optimize_waypoints, true)

    case RouteService.calculate_optimized_route(origin, destination, waypoints, options) do
      {:ok, route_data} ->
        render(conn, :optimized_route, route_data: route_data)
      
      {:error, reason} ->
        {:error, format_route_error(reason)}
    end
  end

  def optimize(_conn, _params) do
    {:error, {:bad_request, "origin, destination, and waypoints are required"}}
  end

  @doc """
  GET /api/routes/alternatives - Get route alternatives
  """
  def alternatives(conn, %{"origin" => origin, "destination" => destination} = params) do
    options = 
      params
      |> build_route_options()
      |> Map.put(:alternatives, true)

    case RouteService.get_route_alternatives(origin, destination, options) do
      {:ok, route_data} ->
        render(conn, :route, route_data: route_data)
      
      {:error, reason} ->
        {:error, format_route_error(reason)}
    end
  end

  def alternatives(_conn, _params) do
    {:error, {:bad_request, "origin and destination are required"}}
  end

  @doc """
  POST /api/routes/estimate - Get route summary (distance/time only)
  """
  def estimate(conn, %{"origin" => origin, "destination" => destination} = params) do
    waypoints = Map.get(params, "waypoints", [])
    options = build_route_options(params)

    case RouteService.calculate_route_summary(origin, destination, waypoints, options) do
      {:ok, summary} ->
        render(conn, :summary, summary: summary)
      
      {:error, reason} ->
        {:error, format_route_error(reason)}
    end
  end

  def estimate(_conn, _params) do
    {:error, {:bad_request, "origin and destination are required"}}
  end

  @doc """
  POST /api/routes/costs - Estimate trip costs
  """
  def estimate_costs(conn, %{"route_data" => route_data} = params) do
    cost_options = %{
      fuel_efficiency: Map.get(params, "fuel_efficiency", 8.0),
      fuel_price: Map.get(params, "fuel_price", 1.50),
      estimated_tolls: Map.get(params, "estimated_tolls", 0.0),
      estimated_parking: Map.get(params, "estimated_parking", 0.0)
    }

    costs = RouteService.estimate_trip_costs(route_data, cost_options)
    render(conn, :costs, costs: costs)
  end

  def estimate_costs(_conn, _params) do
    {:error, {:bad_request, "route_data is required"}}
  end

  # Private helper functions

  defp build_route_options(params) do
    %{}
    |> maybe_add_travel_mode(params)
    |> maybe_add_avoid_options(params)
    |> maybe_add_departure_time(params)
    |> maybe_add_units(params)
  end

  defp maybe_add_travel_mode(options, %{"travel_mode" => mode}) when mode in ["driving", "walking", "bicycling", "transit"] do
    Map.put(options, :travel_mode, mode)
  end
  defp maybe_add_travel_mode(options, _), do: options

  defp maybe_add_avoid_options(options, %{"avoid" => avoid_list}) when is_list(avoid_list) do
    valid_avoid = Enum.filter(avoid_list, &(&1 in ["tolls", "highways", "ferries"]))
    if length(valid_avoid) > 0 do
      Map.put(options, :avoid, valid_avoid)
    else
      options
    end
  end
  defp maybe_add_avoid_options(options, %{"avoid" => avoid}) when avoid in ["tolls", "highways", "ferries"] do
    Map.put(options, :avoid, avoid)
  end
  defp maybe_add_avoid_options(options, _), do: options

  defp maybe_add_departure_time(options, %{"departure_time" => time}) do
    # Convert ISO string to Unix timestamp if needed
    case DateTime.from_iso8601(time) do
      {:ok, datetime, _} ->
        timestamp = DateTime.to_unix(datetime)
        Map.put(options, :departure_time, timestamp)
      _ ->
        # Try parsing as Unix timestamp
        case Integer.parse(time) do
          {timestamp, ""} -> Map.put(options, :departure_time, timestamp)
          _ -> options
        end
    end
  end
  defp maybe_add_departure_time(options, _), do: options

  defp maybe_add_units(options, %{"units" => units}) when units in ["metric", "imperial"] do
    Map.put(options, :units, units)
  end
  defp maybe_add_units(options, _), do: options

  defp format_route_error({:no_routes_found, message}), do: {:bad_request, message}
  defp format_route_error({:quota_exceeded, message}), do: {:service_unavailable, message}
  defp format_route_error({:request_denied, message}), do: {:unauthorized, message}
  defp format_route_error({:api_error, message}), do: {:bad_gateway, message}
  defp format_route_error({:invalid_origin, message}), do: {:bad_request, message}
  defp format_route_error({:invalid_destination, message}), do: {:bad_request, message}
  defp format_route_error({:update_failed, _changeset}), do: {:internal_server_error, "Failed to update trip"}
  defp format_route_error(_), do: {:internal_server_error, "Route calculation failed"}

  # Cache status determination for route data
  defp determine_route_cache_status(route_data) when is_map(route_data) do
    cond do
      # If route_data has fast response time indicators or specific cache markers
      Map.has_key?(route_data, :cached_at) ->
        {:cache_hit, get_current_backend()}

      # Route calculations are typically cached by RouteService
      Map.has_key?(route_data, :distance) and Map.has_key?(route_data, :duration) ->
        {:cache_hit, get_current_backend()}

      # Default assumption for successful route calculations
      true ->
        {:cache_miss, get_current_backend()}
    end
  end

  defp determine_route_cache_status(_), do: :cache_disabled

  defp get_current_backend do
    try do
      RouteWiseApi.Caching.backend()
    rescue
      _ -> :unknown
    end
  end
end