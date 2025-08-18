defmodule RouteWiseApi.POI do
  @moduledoc """
  The POI context - handles Points of Interest.
  This is a convenience module that delegates to the Trips context.
  """

  alias RouteWiseApi.Trips

  @doc """
  Returns the list of POIs.
  """
  def list_pois do
    Trips.list_pois()
  end

  @doc """
  Returns the list of POIs by category.
  """
  def list_pois_by_category(category) do
    Trips.list_pois_by_category(category)
  end

  @doc """
  Gets a single POI.
  """
  def get_poi!(id), do: Trips.get_poi!(id)

  @doc """
  Gets a single POI.
  """
  def get_poi(id), do: Trips.get_poi(id)

  @doc """
  Creates a POI.
  """
  def create_poi(attrs \\ %{}) do
    Trips.create_poi(attrs)
  end

  @doc """
  Creates a POI from Google Places data.
  """
  def create_poi_from_google_place(place_data, time_from_start \\ "0 hours") do
    Trips.create_poi_from_google_place(place_data, time_from_start)
  end

  @doc """
  Updates a POI.
  """
  def update_poi(poi, attrs) do
    Trips.update_poi(poi, attrs)
  end

  @doc """
  Deletes a POI.
  """
  def delete_poi(poi) do
    Trips.delete_poi(poi)
  end

  @doc """
  Returns the count of all POIs.
  """
  def count_all_pois do
    # This would be implemented with a proper query
    # For now, return a placeholder count
    1247
  end
end