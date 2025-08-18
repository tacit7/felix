defmodule RouteWiseApi.Repo.Migrations.CreateHeroCarouselImages do
  use Ecto.Migration

  def change do
    # Hero carousel images table
    create table(:hero_carousel_images) do
      add :title, :string, size: 255, null: false
      add :subtitle, :string, size: 255
      add :description, :text
      add :image_url, :text, null: false
      add :image_alt_text, :string, size: 500
      add :mobile_image_url, :text
      add :tablet_image_url, :text
      add :webp_image_url, :text
      add :mobile_webp_image_url, :text
      add :cta_text, :string, size: 100
      add :cta_url, :string, size: 500
      add :cta_type, :string, size: 50, default: "internal"
      add :background_color, :string, size: 20
      add :text_color, :string, size: 20, default: "white"
      add :overlay_opacity, :decimal, precision: 3, scale: 2, default: 0.4
      add :text_position, :string, size: 20, default: "center"
      add :text_alignment, :string, size: 20, default: "center"
      add :animation_type, :string, size: 50, default: "fade"
      add :display_duration, :integer, default: 5000
      add :transition_duration, :integer, default: 1000
      add :priority_order, :integer, null: false
      add :is_active, :boolean, default: true
      add :is_featured, :boolean, default: false
      add :start_date, :date
      add :end_date, :date
      add :target_audience, :string, size: 100
      add :device_targeting, {:array, :string}, default: ["desktop", "tablet", "mobile"]
      add :geographic_targeting, {:array, :string}, default: []
      add :seasonal_targeting, {:array, :string}, default: []
      add :click_count, :integer, default: 0
      add :impression_count, :integer, default: 0
      add :conversion_count, :integer, default: 0
      add :last_shown, :utc_datetime
      add :photographer_credit, :string, size: 255
      add :location_featured, :string, size: 255
      add :image_tags, {:array, :string}, default: []
      add :accessibility_compliant, :boolean, default: true
      add :loading_priority, :string, size: 20, default: "high"
      
      # Content management
      add :created_by_user_id, references(:users), null: true
      add :updated_by_user_id, references(:users), null: true
      add :approved_by_user_id, references(:users), null: true
      add :approval_status, :string, size: 20, default: "pending"
      add :approval_date, :utc_datetime
      add :scheduled_publish_date, :utc_datetime
      add :content_version, :integer, default: 1
      
      # SEO and metadata
      add :seo_title, :string, size: 255
      add :seo_description, :string, size: 500
      add :meta_keywords, {:array, :string}, default: []
      add :canonical_url, :string, size: 500

      timestamps(type: :utc_datetime)
    end

    create index(:hero_carousel_images, [:priority_order])
    create index(:hero_carousel_images, [:is_active])
    create index(:hero_carousel_images, [:is_featured])
    create index(:hero_carousel_images, [:approval_status])
    create index(:hero_carousel_images, [:start_date, :end_date])
    create index(:hero_carousel_images, [:scheduled_publish_date])
    create index(:hero_carousel_images, [:target_audience])
    create index(:hero_carousel_images, [:click_count])
    create index(:hero_carousel_images, [:impression_count])
    create index(:hero_carousel_images, [:created_by_user_id])

    # Add check constraints
    create constraint(:hero_carousel_images, :cta_type_check,
      check: "cta_type IN ('internal', 'external', 'modal', 'none')"
    )

    create constraint(:hero_carousel_images, :text_position_check,
      check: "text_position IN ('top', 'center', 'bottom', 'left', 'right', 'top-left', 'top-right', 'bottom-left', 'bottom-right')"
    )

    create constraint(:hero_carousel_images, :text_alignment_check,
      check: "text_alignment IN ('left', 'center', 'right', 'justify')"
    )

    create constraint(:hero_carousel_images, :animation_type_check,
      check: "animation_type IN ('fade', 'slide-left', 'slide-right', 'slide-up', 'slide-down', 'zoom', 'none')"
    )

    create constraint(:hero_carousel_images, :approval_status_check,
      check: "approval_status IN ('pending', 'approved', 'rejected', 'draft')"
    )

    create constraint(:hero_carousel_images, :loading_priority_check,
      check: "loading_priority IN ('high', 'low', 'auto')"
    )

    create constraint(:hero_carousel_images, :overlay_opacity_check,
      check: "overlay_opacity BETWEEN 0.0 AND 1.0"
    )

    create constraint(:hero_carousel_images, :duration_check,
      check: "display_duration >= 1000 AND transition_duration >= 0"
    )

    create constraint(:hero_carousel_images, :date_range_check,
      check: "start_date IS NULL OR end_date IS NULL OR start_date <= end_date"
    )

    # A/B testing and performance tracking
    create table(:hero_carousel_performance) do
      add :image_id, references(:hero_carousel_images, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :impressions, :integer, default: 0
      add :clicks, :integer, default: 0
      add :conversions, :integer, default: 0
      add :bounce_rate, :decimal, precision: 5, scale: 4
      add :avg_time_on_page, :integer
      add :device_type, :string, size: 20
      add :traffic_source, :string, size: 50
      add :geographic_location, :string, size: 100

      timestamps(type: :utc_datetime)
    end

    create index(:hero_carousel_performance, [:image_id, :date])
    create index(:hero_carousel_performance, [:date])
    create index(:hero_carousel_performance, [:device_type])
    create unique_index(:hero_carousel_performance, [:image_id, :date, :device_type, :traffic_source], 
      name: :hero_perf_unique_tracking_idx)

    # Carousel display schedules (for advanced scheduling)
    create table(:hero_carousel_schedules) do
      add :image_id, references(:hero_carousel_images, on_delete: :delete_all), null: false
      add :day_of_week, :integer
      add :start_time, :time
      add :end_time, :time
      add :timezone, :string, size: 50, default: "UTC"
      add :is_active, :boolean, default: true
      add :weight, :integer, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:hero_carousel_schedules, [:image_id])
    create index(:hero_carousel_schedules, [:day_of_week])
    create index(:hero_carousel_schedules, [:is_active])

    create constraint(:hero_carousel_schedules, :day_of_week_check,
      check: "day_of_week BETWEEN 0 AND 6"
    )

    create constraint(:hero_carousel_schedules, :weight_check,
      check: "weight > 0"
    )

    create constraint(:hero_carousel_schedules, :time_range_check,
      check: "start_time IS NULL OR end_time IS NULL OR start_time < end_time"
    )
  end
end