defmodule RouteWiseApiWeb.RoutesJSON do
  import RouteWiseApiWeb.CacheHelpers

  @doc """
  Renders a calculated route.
  """
  def route(%{route_data: route_data} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: format_route_data(route_data)}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders an optimized route with waypoint order.
  """
  def optimized_route(%{route_data: route_data} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      data: format_route_data(route_data),
      waypoint_order: route_data[:waypoint_order] || []
    }
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders a route summary (distance/time only).
  """
  def summary(%{summary: summary} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{data: summary}
    |> maybe_add_cache_meta(cache_info)
  end

  @doc """
  Renders trip cost estimates.
  """
  def costs(%{costs: costs} = assigns) do
    cache_info = Map.get(assigns, :cache_info)
    
    %{
      data: %{
        fuel: format_currency(costs.fuel),
        tolls: format_currency(costs.tolls),
        parking: format_currency(costs.parking),
        total: format_currency(costs.total),
        breakdown: %{
          fuel_raw: costs.fuel,
          tolls_raw: costs.tolls,
          parking_raw: costs.parking,
          total_raw: costs.total
        }
      }
    }
    |> maybe_add_cache_meta(cache_info)
  end

  defp format_route_data(route_data) do
    %{
      distance: route_data[:distance],
      duration: route_data[:duration],
      start_address: route_data[:start_address],
      end_address: route_data[:end_address],
      polyline: route_data[:polyline],
      legs: format_legs(route_data[:legs] || []),
      route_points: route_data[:route_points] || [],
      bounds: route_data[:bounds],
      warnings: route_data[:warnings] || []
    }
  end

  defp format_legs(legs) do
    Enum.map(legs, fn leg ->
      %{
        distance: leg[:distance],
        duration: leg[:duration],
        start_address: leg[:start_address],
        end_address: leg[:end_address],
        start_location: leg[:start_location],
        end_location: leg[:end_location],
        steps: format_steps(leg[:steps] || [])
      }
    end)
  end

  defp format_steps(steps) do
    Enum.map(steps, fn step ->
      %{
        distance: step[:distance],
        duration: step[:duration],
        instructions: step[:html_instructions],
        start_location: step[:start_location],
        end_location: step[:end_location],
        travel_mode: step[:travel_mode]
      }
    end)
  end

  defp format_currency(amount) when is_float(amount) do
    :erlang.float_to_binary(amount, decimals: 2)
  end
  defp format_currency(_amount), do: "0.00"
end