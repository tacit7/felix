defmodule RouteWiseApi.ResponseBuilder do
  @moduledoc """
  Service for building consistent API responses across controllers.
  
  Handles:
  - Success response building with metadata
  - Error response building with consistent structure
  - Cache metadata injection for development
  - Response validation and logging
  """
  
  alias RouteWiseApi.{CacheService, ErrorCodes}
  
  require Logger

  @doc """
  Build a successful explore results response.
  """
  def build_explore_response(pois, formatted_pois, location_name, location_data, additional_meta) do
    maps_api_key = get_maps_api_key()

    # Determine cache status for the response
    cache_info = CacheService.determine_explore_results_cache_status(pois)

    base_meta = %{
      total_pois: length(pois),
      location: location_name,
      maps_available: not is_nil(maps_api_key),
      bounds_source: location_data && location_data.bounds_source
    }

    # Extract rich geographic context from location_data
    location_context = if location_data do
      %{
        state: location_data.state,
        country: location_data.country,
        country_code: location_data.country_code,
        formatted_address: location_data.formatted_address,
        display_name: location_data.display_name,
        metadata: location_data.metadata
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)  # Remove nil values
      |> Enum.into(%{})
    else
      %{}
    end

    response = %{
      success: true,
      data: %{
        pois: formatted_pois,
        location: location_name,
        location_coords: location_data && location_data.coords,
        bounds: location_data && location_data.bounds,
        # Include rich geographic context
        location_context: location_context,
        maps_api_key: maps_api_key,
        meta: Map.merge(base_meta, additional_meta)
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }


    # Add cache metadata in development
    maybe_add_cache_metadata(response, cache_info)
  end

  @doc """
  Build a successful disambiguation response.
  """
  def build_disambiguation_response(location, suggestions) do
    %{
      success: true,
      data: %{
        query: location,
        suggestions: suggestions,
        count: length(suggestions),
        is_ambiguous: length(suggestions) > 1
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Build a consistent error response.
  """
  def build_error_response(message, error_code, details) do
    %{
      success: false,
      error: %{
        message: message,
        code: error_code,
        details: details
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Build error response for place not found.
  """
  def build_place_not_found_error(place_id) do
    build_error_response(
      "Cached place not found", 
      ErrorCodes.place_not_found(), 
      ["No cached place found with ID: #{place_id}"]
    )
  end

  @doc """
  Build error response for missing parameters.
  """
  def build_missing_parameter_error(parameter_info) do
    build_error_response(
      "Missing required parameter: #{parameter_info.name}",
      ErrorCodes.missing_parameter(),
      [parameter_info.message]
    )
  end

  @doc """
  Build error response for internal server errors.
  """
  def build_internal_server_error(context, exception) do
    build_error_response(
      "Failed to #{context}",
      ErrorCodes.explore_results_error(),
      [Exception.message(exception)]
    )
  end

  @doc """
  Build error response for disambiguation failures.
  """
  def build_disambiguation_error(reason) do
    build_error_response(
      "No suggestions found for location",
      ErrorCodes.no_suggestions(),
      [reason]
    )
  end

  # Private helper functions

  defp get_maps_api_key do
    System.get_env("GOOGLE_MAPS_API_KEY")
  end

  defp maybe_add_cache_metadata(response, cache_info) do
    if Mix.env() == :dev do
      import RouteWiseApiWeb.CacheHelpers
      maybe_add_cache_meta(response, cache_info)
    else
      response
    end
  end
end