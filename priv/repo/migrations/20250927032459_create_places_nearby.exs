defmodule RouteWiseApi.Repo.Migrations.CreatePlacesNearby do
  use Ecto.Migration

  def change do
    create table(:places_nearby) do
      # Relationship to main place
      add :place_id, references(:places, on_delete: :delete_all), null: false

      # Core nearby place information
      add :nearby_place_name, :string, null: false
      add :recommendation_reason, :text, null: false
      add :description, :text

      # Geographic information
      add :latitude, :decimal, precision: 10, scale: 6
      add :longitude, :decimal, precision: 10, scale: 6
      add :distance_km, :decimal, precision: 8, scale: 2
      add :travel_time_minutes, :integer
      add :transportation_method, :string # "driving", "walking", "public_transport", "flight"

      # Place details
      add :place_type, :string # "city", "town", "attraction", "landmark", "neighborhood"
      add :country_code, :string, size: 2
      add :state_province, :string
      add :popularity_score, :integer, default: 0

      # Recommendation metadata
      add :recommendation_category, :string # "day_trip", "base_city", "hidden_gem", "cultural_site"
      add :best_season, :string # "spring", "summer", "fall", "winter", "year_round"
      add :difficulty_level, :string # "easy", "moderate", "challenging"
      add :estimated_visit_duration, :string # "2-3 hours", "half_day", "full_day", "2-3 days"

      # External references (optional)
      add :google_place_id, :string
      add :location_iq_place_id, :string
      add :wikipedia_url, :string
      add :official_website, :string

      # Content and media
      add :tips, {:array, :string}, default: []
      add :image_url, :string
      add :image_attribution, :string

      # Metadata
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0
      add :source, :string, default: "manual" # "manual", "api", "crowdsourced"
      add :verified, :boolean, default: false
      add :last_verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Primary relationship index
    create index(:places_nearby, [:place_id])

    # Query optimization indexes
    create index(:places_nearby, [:place_id, :is_active, :sort_order])
    create index(:places_nearby, [:recommendation_category])
    create index(:places_nearby, [:place_type])
    create index(:places_nearby, [:distance_km])
    create index(:places_nearby, [:popularity_score])

    # External ID indexes
    create index(:places_nearby, [:google_place_id])
    create index(:places_nearby, [:location_iq_place_id])

    # Geographic queries
    create index(:places_nearby, [:latitude, :longitude])
  end
end
