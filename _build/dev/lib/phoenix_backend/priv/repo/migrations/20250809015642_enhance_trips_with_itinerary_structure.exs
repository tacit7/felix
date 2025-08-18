defmodule RouteWiseApi.Repo.Migrations.EnhanceTripsWithItineraryStructure do
  use Ecto.Migration

  def change do
    alter table(:trips) do
      # Enhanced trip planning fields
      add :start_date, :date
      add :end_date, :date
      add :start_location, :map  # {name, lat, lng, place_id}
      add :end_location, :map    # {name, lat, lng, place_id}
      
      # Core itinerary structure - replaces separate itinerary table
      add :days, :map, default: %{"days" => []}  # Array of day objects with activities
      
      # Enhanced metadata
      add :total_distance_km, :decimal, precision: 10, scale: 2
      add :estimated_cost, :decimal, precision: 10, scale: 2
      add :difficulty_level, :string, default: "moderate"  # easy, moderate, challenging
      add :trip_tags, {:array, :string}, default: []  # ["family-friendly", "budget", "adventure"]
      add :weather_requirements, :map  # Weather preferences/restrictions
      add :packing_list, {:array, :string}, default: []
      
      # Status tracking
      add :status, :string, default: "planning"  # planning, confirmed, in_progress, completed, cancelled
      add :last_modified_by_user_at, :utc_datetime
    end

    # Indexes for efficient querying
    create index(:trips, [:start_date])
    create index(:trips, [:end_date])
    create index(:trips, [:status])
    create index(:trips, [:difficulty_level])
    create index(:trips, [:trip_tags], using: :gin)  # For array searches
    create index(:trips, [:last_modified_by_user_at])
  end
end
