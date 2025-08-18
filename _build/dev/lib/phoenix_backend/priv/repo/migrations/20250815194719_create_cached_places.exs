defmodule RouteWiseApi.Repo.Migrations.CreateCachedPlaces do
  use Ecto.Migration

  def change do
    # Enable extensions first
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm")
    
    create table(:cached_places, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :place_type, :integer, null: false  # 1=country, 3=city, 5=poi
      add :country_code, :string, size: 2
      add :admin1_code, :string
      add :lat, :float
      add :lon, :float
      add :popularity_score, :integer, default: 0
      add :search_count, :integer, default: 0  # Track usage for popularity
      add :source, :string, default: "manual"  # manual, locationiq, google
      
      timestamps(type: :utc_datetime)
    end

    # Indexes for fast autocomplete queries
    create index(:cached_places, [:place_type, :popularity_score])
    create index(:cached_places, [:country_code, :place_type])
    create index(:cached_places, [:search_count])
    
    # Create indexes with raw SQL for proper syntax
    execute("CREATE INDEX cached_places_name_gin_idx ON cached_places USING gin (name gin_trgm_ops)")
    execute("CREATE INDEX cached_places_name_prefix_idx ON cached_places (name text_pattern_ops)")
  end
end
