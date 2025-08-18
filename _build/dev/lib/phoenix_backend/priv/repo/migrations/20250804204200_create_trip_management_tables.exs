defmodule RouteWiseApi.Repo.Migrations.CreateTripManagementTables do
  use Ecto.Migration

  def change do
    # Interest categories table - defines available interest types
    create table(:interest_categories) do
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :description, :text
      add :icon_name, :string
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:interest_categories, [:name])

    # User interests junction table - many-to-many relationship
    create table(:user_interests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :category_id, references(:interest_categories, on_delete: :delete_all), null: false
      add :is_enabled, :boolean, default: true
      add :priority, :integer, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:user_interests, [:user_id])
    create index(:user_interests, [:category_id])
    create unique_index(:user_interests, [:user_id, :category_id])

    # POIs table (from frontend schema)
    create table(:pois) do
      add :name, :string, null: false
      add :description, :text, null: false
      add :category, :string, null: false
      add :rating, :decimal, precision: 2, scale: 1, null: false
      add :review_count, :integer, null: false
      add :time_from_start, :string, null: false
      add :image_url, :string, null: false
      add :place_id, :string
      add :address, :string
      add :price_level, :integer
      add :is_open, :boolean

      timestamps(type: :utc_datetime)
    end

    create index(:pois, [:category])
    create index(:pois, [:rating])
    create index(:pois, [:place_id])

    # Trips table (from frontend schema) 
    create table(:trips) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :title, :string, null: false
      add :start_city, :string, null: false
      add :end_city, :string, null: false
      add :checkpoints, :map, default: %{}
      add :route_data, :map
      add :pois_data, :map, default: %{}
      add :is_public, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:trips, [:user_id])
    create index(:trips, [:is_public])
    create index(:trips, [:start_city])
    create index(:trips, [:end_city])
  end
end
