defmodule RouteWiseApi.Repo.Migrations.CreateHiddenGems do
  use Ecto.Migration

  def change do
    # Hidden gems table
    create table(:hidden_gems) do
      add :name, :string, size: 255, null: false
      add :subtitle, :string, size: 255
      add :description, :text
      add :image_url, :text
      add :location, :string, size: 255
      add :city, :string, size: 100
      add :state, :string, size: 50
      add :country, :string, size: 50, default: "USA"
      add :latitude, :decimal, precision: 10, scale: 6
      add :longitude, :decimal, precision: 10, scale: 6
      add :category, :string, size: 50
      add :subcategory, :string, size: 50
      add :difficulty_level, :string, size: 20
      add :best_time_to_visit, :string, size: 100
      add :estimated_duration, :string, size: 50
      add :accessibility_level, :string, size: 20
      add :crowd_level, :string, size: 20
      add :cost_estimate, :string, size: 100
      add :insider_tip, :text
      add :how_to_get_there, :text
      add :parking_info, :text
      add :facilities_available, {:array, :string}, default: []
      add :seasonal_notes, :text
      add :photography_tips, :text
      add :nearby_attractions, {:array, :string}, default: []
      add :local_guides_available, :boolean, default: false
      add :requires_permits, :boolean, default: false
      add :permit_info, :text
      add :safety_notes, :text
      add :weather_dependency, :string, size: 50
      add :is_featured, :boolean, default: false
      add :is_active, :boolean, default: true
      add :visibility_score, :integer, default: 50
      add :uniqueness_score, :integer, default: 50
      add :difficulty_score, :integer, default: 50
      add :overall_rating, :decimal, precision: 3, scale: 2
      add :total_votes, :integer, default: 0
      add :featured_order, :integer
      add :discovery_date, :date
      add :last_verified, :date
      
      # Google Places integration
      add :google_place_id, :string, size: 255
      add :google_rating, :decimal, precision: 3, scale: 2
      add :google_reviews_count, :integer
      add :google_phone, :string, size: 50
      add :google_website, :string, size: 500
      add :google_opening_hours, :map
      add :google_price_level, :integer
      add :google_types, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:hidden_gems, [:city, :state])
    create index(:hidden_gems, [:category])
    create index(:hidden_gems, [:subcategory])
    create index(:hidden_gems, [:is_featured])
    create index(:hidden_gems, [:is_active])
    create index(:hidden_gems, [:featured_order])
    create index(:hidden_gems, [:visibility_score])
    create index(:hidden_gems, [:uniqueness_score])
    create index(:hidden_gems, [:overall_rating])
    create index(:hidden_gems, [:latitude, :longitude])
    create unique_index(:hidden_gems, [:google_place_id], where: "google_place_id IS NOT NULL")

    # Add check constraints
    create constraint(:hidden_gems, :difficulty_level_check,
      check: "difficulty_level IN ('Easy', 'Moderate', 'Challenging', 'Expert')"
    )

    create constraint(:hidden_gems, :accessibility_level_check,
      check: "accessibility_level IN ('High', 'Medium', 'Low', 'None')"
    )

    create constraint(:hidden_gems, :crowd_level_check,
      check: "crowd_level IN ('Very Low', 'Low', 'Moderate', 'High', 'Very High')"
    )

    create constraint(:hidden_gems, :weather_dependency_check,
      check: "weather_dependency IN ('Low', 'Medium', 'High', 'Critical')"
    )

    create constraint(:hidden_gems, :score_range_check,
      check: "visibility_score BETWEEN 0 AND 100 AND uniqueness_score BETWEEN 0 AND 100 AND difficulty_score BETWEEN 0 AND 100"
    )

    # Hidden gem tags (normalized many-to-many)
    create table(:hidden_gem_tags) do
      add :name, :string, size: 50, null: false
      add :display_name, :string, size: 100, null: false
      add :color, :string, size: 20
      add :icon, :string, size: 50
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:hidden_gem_tags, [:name])
    create index(:hidden_gem_tags, [:is_active])

    # Join table for hidden gems and tags
    create table(:hidden_gems_tags) do
      add :hidden_gem_id, references(:hidden_gems, on_delete: :delete_all), null: false
      add :tag_id, references(:hidden_gem_tags, on_delete: :delete_all), null: false
    end

    create unique_index(:hidden_gems_tags, [:hidden_gem_id, :tag_id])
    create index(:hidden_gems_tags, [:tag_id])

    # Hidden gem photos
    create table(:hidden_gem_photos) do
      add :hidden_gem_id, references(:hidden_gems, on_delete: :delete_all), null: false
      add :url, :text, null: false
      add :caption, :string, size: 500
      add :photographer_credit, :string, size: 255
      add :is_primary, :boolean, default: false
      add :display_order, :integer, default: 0
      add :photo_type, :string, size: 50, default: "general"
      add :season, :string, size: 20
      add :time_of_day, :string, size: 20

      timestamps(type: :utc_datetime)
    end

    create index(:hidden_gem_photos, [:hidden_gem_id])
    create index(:hidden_gem_photos, [:is_primary])
    create index(:hidden_gem_photos, [:display_order])
    create index(:hidden_gem_photos, [:photo_type])

    # Hidden gem reviews/experiences
    create table(:hidden_gem_experiences) do
      add :hidden_gem_id, references(:hidden_gems, on_delete: :delete_all), null: false
      add :visitor_name, :string, size: 255
      add :visit_date, :date
      add :experience_text, :text
      add :rating, :integer
      add :visit_duration, :string, size: 50
      add :visit_season, :string, size: 20
      add :travel_party_size, :integer
      add :travel_party_type, :string, size: 50
      add :helpful_tips, :text
      add :would_return, :boolean
      add :is_approved, :boolean, default: false
      add :is_featured, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:hidden_gem_experiences, [:hidden_gem_id])
    create index(:hidden_gem_experiences, [:is_approved])
    create index(:hidden_gem_experiences, [:is_featured])
    create index(:hidden_gem_experiences, [:rating])
    create index(:hidden_gem_experiences, [:visit_date])

    create constraint(:hidden_gem_experiences, :rating_check,
      check: "rating BETWEEN 1 AND 5"
    )
  end
end