defmodule RouteWiseApi.Repo.Migrations.CreateWeeklyFeaturedTrips do
  use Ecto.Migration

  def change do
    # Weekly featured trips table
    create table(:weekly_featured_trips) do
      add :slug, :string, size: 100, null: false
      add :title, :string, size: 255, null: false
      add :subtitle, :string, size: 255
      add :description, :text
      add :image_url, :text
      add :duration, :string, size: 50
      add :difficulty, :string, size: 20
      add :best_time, :string, size: 100
      add :total_miles, :string, size: 50
      add :estimated_cost, :string, size: 100
      add :trending_metric, :string, size: 100
      add :is_active, :boolean, default: true
      add :week_priority, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:weekly_featured_trips, [:slug])
    create index(:weekly_featured_trips, [:is_active])
    create index(:weekly_featured_trips, [:week_priority])

    # Add check constraint for difficulty
    create constraint(:weekly_featured_trips, :difficulty_check,
      check: "difficulty IN ('Easy', 'Moderate', 'Challenging')"
    )

    # Trip highlights (normalized)
    create table(:weekly_trip_highlights) do
      add :trip_id, references(:weekly_featured_trips, on_delete: :delete_all), null: false
      add :highlight, :string, size: 255, null: false
      add :order_index, :integer, default: 0
    end

    create index(:weekly_trip_highlights, [:trip_id])
    create index(:weekly_trip_highlights, [:order_index])

    # Trip stats/metadata
    create table(:weekly_trip_stats) do
      add :trip_id, references(:weekly_featured_trips, on_delete: :delete_all), null: false
      add :stat_type, :string, size: 50, null: false
      add :stat_value, :string, size: 100, null: false
      add :icon, :string, size: 50
    end

    create index(:weekly_trip_stats, [:trip_id])
    create index(:weekly_trip_stats, [:stat_type])
  end
end
