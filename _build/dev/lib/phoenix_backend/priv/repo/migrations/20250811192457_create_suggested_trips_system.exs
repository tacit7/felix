defmodule RouteWiseApi.Repo.Migrations.CreateSuggestedTripsSystem do
  use Ecto.Migration

  def change do
    # Suggested trips table - main trip templates
    create table(:suggested_trips) do
      add :slug, :string, size: 100, null: false
      add :title, :string, size: 255, null: false
      add :summary, :text
      add :description, :text
      add :duration, :string, size: 50
      add :difficulty, :string, size: 20
      add :best_time, :string, size: 100
      add :estimated_cost, :string, size: 100
      add :hero_image, :text
      add :tips, {:array, :string}, default: []
      add :tags, {:array, :string}, default: []
      add :is_active, :boolean, default: true
      add :featured_order, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:suggested_trips, [:slug])
    create index(:suggested_trips, [:difficulty])
    create index(:suggested_trips, [:is_active])
    create index(:suggested_trips, [:featured_order])

    # Add check constraint for difficulty
    create constraint(:suggested_trips, :difficulty_check,
      check: "difficulty IN ('Easy', 'Moderate', 'Challenging')"
    )

    # Trip places - points of interest for each trip
    create table(:trip_places) do
      add :trip_id, references(:suggested_trips, on_delete: :delete_all), null: false
      add :name, :string, size: 255, null: false
      add :description, :text
      add :image, :text
      add :latitude, :decimal, precision: 10, scale: 8
      add :longitude, :decimal, precision: 11, scale: 8
      add :activities, {:array, :string}, default: []
      add :best_time_to_visit, :string, size: 100
      add :order_index, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:trip_places, [:trip_id])
    create index(:trip_places, [:order_index])
    create index(:trip_places, [:latitude, :longitude])

    # Trip itinerary - day-by-day schedule
    create table(:trip_itinerary) do
      add :trip_id, references(:suggested_trips, on_delete: :delete_all), null: false
      add :day, :integer, null: false
      add :title, :string, size: 255, null: false
      add :location, :string, size: 255
      add :activities, {:array, :string}, default: []
      add :highlights, {:array, :string}, default: []
      add :estimated_time, :string, size: 50
      add :driving_time, :string, size: 50
      add :order_index, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:trip_itinerary, [:trip_id])
    create index(:trip_itinerary, [:trip_id, :day])
    create index(:trip_itinerary, [:order_index])

    # Ensure day numbers are positive
    create constraint(:trip_itinerary, :day_positive,
      check: "day > 0"
    )
  end
end