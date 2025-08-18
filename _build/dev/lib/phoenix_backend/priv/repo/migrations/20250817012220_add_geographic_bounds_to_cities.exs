defmodule RouteWiseApi.Repo.Migrations.AddGeographicBoundsToCities do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      # Geographic bounding box for the location (for calculating appropriate search radius)
      add :bbox_north, :decimal, precision: 10, scale: 7  # Northernmost latitude
      add :bbox_south, :decimal, precision: 10, scale: 7  # Southernmost latitude  
      add :bbox_east, :decimal, precision: 10, scale: 7   # Easternmost longitude
      add :bbox_west, :decimal, precision: 10, scale: 7   # Westernmost longitude
      
      # Calculated search radius in meters (derived from bounding box)
      add :search_radius_meters, :integer
      
      # Source of the geographic data
      add :bounds_source, :string, default: "osm"  # "osm", "manual", etc
      
      # When the bounds were last updated
      add :bounds_updated_at, :utc_datetime
    end
  end
end