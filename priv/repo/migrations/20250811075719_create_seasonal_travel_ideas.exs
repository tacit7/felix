defmodule RouteWiseApi.Repo.Migrations.CreateSeasonalTravelIdeas do
  use Ecto.Migration

  def change do
    # Seasonal travel categories table
    create table(:seasonal_travel_categories) do
      add :name, :string, size: 50, null: false
      add :display_name, :string, size: 100, null: false
      add :description, :text
      add :icon, :string, size: 50
      add :color, :string, size: 20
      add :is_active, :boolean, default: true
      add :display_order, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:seasonal_travel_categories, [:name])
    create index(:seasonal_travel_categories, [:is_active])
    create index(:seasonal_travel_categories, [:display_order])

    # Seasonal travel ideas table
    create table(:seasonal_travel_ideas) do
      add :category_id, references(:seasonal_travel_categories, on_delete: :restrict), null: false
      add :title, :string, size: 255, null: false
      add :subtitle, :string, size: 255
      add :description, :text
      add :image_url, :text
      add :destination, :string, size: 255
      add :best_months, :string, size: 100
      add :duration, :string, size: 50
      add :difficulty, :string, size: 20
      add :estimated_cost, :string, size: 100
      add :temperature_range, :string, size: 50
      add :featured_activities, {:array, :string}, default: []
      add :travel_tips, {:array, :string}, default: []
      add :is_featured, :boolean, default: false
      add :is_active, :boolean, default: true
      add :priority, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:seasonal_travel_ideas, [:category_id])
    create index(:seasonal_travel_ideas, [:is_featured])
    create index(:seasonal_travel_ideas, [:is_active])
    create index(:seasonal_travel_ideas, [:priority])
    create index(:seasonal_travel_ideas, [:best_months])

    # Add check constraint for difficulty
    create constraint(:seasonal_travel_ideas, :seasonal_difficulty_check,
      check: "difficulty IN ('Easy', 'Moderate', 'Challenging')"
    )

    # Seasonal travel highlights (normalized)
    create table(:seasonal_travel_highlights) do
      add :travel_idea_id, references(:seasonal_travel_ideas, on_delete: :delete_all), null: false
      add :highlight, :string, size: 255, null: false
      add :icon, :string, size: 50
      add :order_index, :integer, default: 0
    end

    create index(:seasonal_travel_highlights, [:travel_idea_id])
    create index(:seasonal_travel_highlights, [:order_index])

    # Weather information
    create table(:seasonal_weather_info) do
      add :travel_idea_id, references(:seasonal_travel_ideas, on_delete: :delete_all), null: false
      add :month, :string, size: 20, null: false
      add :avg_high_temp, :integer
      add :avg_low_temp, :integer
      add :precipitation, :string, size: 50
      add :weather_description, :string, size: 255
    end

    create index(:seasonal_weather_info, [:travel_idea_id])
    create index(:seasonal_weather_info, [:month])
    create unique_index(:seasonal_weather_info, [:travel_idea_id, :month])
  end
end