defmodule RouteWiseApi.GoogleDirections do
  @moduledoc """
  Google Directions API client for route calculations.
  """

  require Logger

  @base_url "https://maps.googleapis.com/maps/api/directions/json"

  @doc """
  Calculate route between origin and destination with optional waypoints.
  
  ## Parameters
  - origin: Starting location (address string or lat,lng)
  - destination: Ending location (address string or lat,lng)
  - waypoints: List of intermediate stops (optional)
  - options: Additional options like travel_mode, avoid, etc.
  
  ## Returns
  {:ok, route_data} or {:error, reason}
  """
  def calculate_route(origin, destination, waypoints \\ [], options \\ %{}) do
    params = build_request_params(origin, destination, waypoints, options)
    
    case make_request(params) do
      {:ok, response} -> parse_directions_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Optimize the order of waypoints for the most efficient route.
  """
  def optimize_waypoints(origin, destination, waypoints, options \\ %{}) do
    options = Map.put(options, :optimize_waypoints, true)
    calculate_route(origin, destination, waypoints, options)
  end

  @doc """
  Get multiple route alternatives between two points.
  """
  def get_route_alternatives(origin, destination, options \\ %{}) do
    options = Map.put(options, :alternatives, true)
    calculate_route(origin, destination, [], options)
  end

  # Private functions

  defp build_request_params(origin, destination, waypoints, options) do
    base_params = %{
      origin: format_location(origin),
      destination: format_location(destination),
      key: get_api_key()
    }

    base_params
    |> maybe_add_waypoints(waypoints)
    |> maybe_add_travel_mode(options)
    |> maybe_add_avoid(options)
    |> maybe_add_alternatives(options)
    |> maybe_add_optimize_waypoints(options)
    |> maybe_add_departure_time(options)
    |> maybe_add_units(options)
  end

  defp format_location(%{lat: lat, lng: lng}), do: "#{lat},#{lng}"
  defp format_location(%{"lat" => lat, "lng" => lng}), do: "#{lat},#{lng}"
  defp format_location(address) when is_binary(address), do: address
  defp format_location(_), do: ""

  defp maybe_add_waypoints(params, []), do: params
  defp maybe_add_waypoints(params, waypoints) do
    waypoints_str = 
      waypoints
      |> Enum.map(&format_location/1)
      |> Enum.join("|")
    
    Map.put(params, :waypoints, waypoints_str)
  end

  defp maybe_add_travel_mode(params, %{travel_mode: mode}) do
    Map.put(params, :mode, mode)
  end
  defp maybe_add_travel_mode(params, _), do: Map.put(params, :mode, "driving")

  defp maybe_add_avoid(params, %{avoid: avoid_options}) when is_list(avoid_options) do
    avoid_str = Enum.join(avoid_options, "|")
    Map.put(params, :avoid, avoid_str)
  end
  defp maybe_add_avoid(params, %{avoid: avoid_option}) do
    Map.put(params, :avoid, avoid_option)
  end
  defp maybe_add_avoid(params, _), do: params

  defp maybe_add_alternatives(params, %{alternatives: true}) do
    Map.put(params, :alternatives, "true")
  end
  defp maybe_add_alternatives(params, _), do: params

  defp maybe_add_optimize_waypoints(params, %{optimize_waypoints: true}) do
    current_waypoints = Map.get(params, :waypoints, "")
    if current_waypoints != "" do
      Map.put(params, :waypoints, "optimize:true|#{current_waypoints}")
    else
      params
    end
  end
  defp maybe_add_optimize_waypoints(params, _), do: params

  defp maybe_add_departure_time(params, %{departure_time: time}) do
    Map.put(params, :departure_time, time)
  end
  defp maybe_add_departure_time(params, _), do: params

  defp maybe_add_units(params, %{units: units}) do
    Map.put(params, :units, units)
  end
  defp maybe_add_units(params, _), do: Map.put(params, :units, "metric")

  defp make_request(params) do
    url = @base_url <> "?" <> URI.encode_query(params)
    
    Logger.info("Making Google Directions API request: #{inspect(Map.drop(params, [:key]))}")
    
    case Finch.build(:get, url) |> Finch.request(RouteWiseApi.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, {:decode_error, "Failed to decode JSON response"}}
        end
      
      {:ok, %Finch.Response{status: status, body: body}} ->
        Logger.error("Google Directions API error: #{status} - #{body}")
        {:error, {:api_error, status, body}}
      
      {:error, reason} ->
        Logger.error("Failed to make request to Google Directions API: #{inspect(reason)}")
        {:error, {:request_error, reason}}
    end
  rescue
    e ->
      Logger.error("Exception in Google Directions API request: #{inspect(e)}")
      {:error, {:exception, e}}
  end

  defp parse_directions_response(%{"status" => "OK", "routes" => routes}) when length(routes) > 0 do
    route = List.first(routes)
    {:ok, format_route_data(route)}
  end

  defp parse_directions_response(%{"status" => "ZERO_RESULTS"}) do
    {:error, {:no_routes_found, "No routes found between the specified locations"}}
  end

  defp parse_directions_response(%{"status" => "OVER_QUERY_LIMIT"}) do
    {:error, {:quota_exceeded, "API quota exceeded"}}
  end

  defp parse_directions_response(%{"status" => "REQUEST_DENIED", "error_message" => message}) do
    {:error, {:request_denied, message}}
  end

  defp parse_directions_response(%{"status" => status}) do
    {:error, {:api_error, "API returned status: #{status}"}}
  end

  defp parse_directions_response(_response) do
    {:error, {:parse_error, "Unexpected API response format"}}
  end

  defp format_route_data(route) do
    leg = route["legs"] |> List.first()
    
    %{
      distance: leg["distance"]["text"],
      duration: leg["duration"]["text"],
      start_address: leg["start_address"],
      end_address: leg["end_address"],
      polyline: route["overview_polyline"]["points"],
      legs: format_legs(route["legs"]),
      route_points: decode_polyline(route["overview_polyline"]["points"]),
      bounds: route["bounds"],
      warnings: route["warnings"] || [],
      waypoint_order: route["waypoint_order"] || []
    }
  end

  defp format_legs(legs) do
    Enum.map(legs, fn leg ->
      %{
        distance: leg["distance"]["text"],
        duration: leg["duration"]["text"], 
        start_address: leg["start_address"],
        end_address: leg["end_address"],
        start_location: leg["start_location"],
        end_location: leg["end_location"],
        steps: format_steps(leg["steps"])
      }
    end)
  end

  defp format_steps(steps) do
    Enum.map(steps, fn step ->
      %{
        distance: step["distance"]["text"],
        duration: step["duration"]["text"],
        html_instructions: step["html_instructions"],
        start_location: step["start_location"],
        end_location: step["end_location"],
        travel_mode: step["travel_mode"]
      }
    end)
  end

  # Simple polyline decoder - for production, consider using a more robust library
  defp decode_polyline(_polyline) do
    # This is a simplified version - in production you might want to use
    # a proper polyline decoding library or implement the full algorithm
    try do
      # For now, return empty array - implementing full polyline decoding
      # is complex and might be better handled by a dedicated library
      []
    rescue
      _ -> []
    end
  end

  defp get_api_key do
    System.get_env("GOOGLE_DIRECTIONS_API_KEY") ||
      Application.get_env(:phoenix_backend, :google_directions_api_key) ||
      raise "Google Directions API key not configured. Set GOOGLE_DIRECTIONS_API_KEY environment variable."
  end
end