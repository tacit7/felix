defmodule RouteWiseApi.Repo.Migrations.CreatePlacesSearchWithAliases do
  use Ecto.Migration

  def up do
    # Enable required extensions
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS unaccent"

    # Create immutable wrapper for unaccent function
    execute """
    CREATE OR REPLACE FUNCTION immutable_unaccent(text)
    RETURNS text AS
    $func$
    BEGIN
      RETURN unaccent($1);
    END;
    $func$ LANGUAGE plpgsql IMMUTABLE;
    """

    # Create places table for searchable places
    create table(:places, primary_key: false) do
      add :id, :serial, primary_key: true
      add :name, :string, null: false
      add :code, :string, null: true  # e.g., "USVI", "NYC", "LAX"
      add :kind, :string, null: false  # "country", "region", "city", "poi"
      add :latitude, :decimal, precision: 10, scale: 6
      add :longitude, :decimal, precision: 10, scale: 6
      add :popularity, :integer, default: 0
      add :metadata, :map, default: %{}

      # Generated normalized column for trigram search
      add :canonical_norm, :string,
          null: false,
          generated: "ALWAYS AS (lower(immutable_unaccent(name))) STORED"

      timestamps(type: :utc_datetime)
    end

    # Create place_aliases table for alternative names
    create table(:place_aliases, primary_key: false) do
      add :id, :serial, primary_key: true
      add :place_id, references(:places, on_delete: :delete_all), null: false
      add :alias, :string, null: false
      add :priority, :integer, default: 0  # Higher priority aliases ranked first

      # Generated normalized column for trigram search
      add :alias_norm, :string,
          null: false,
          generated: "ALWAYS AS (lower(immutable_unaccent(alias))) STORED"

      timestamps(type: :utc_datetime)
    end

    # Create indexes
    # Unique index on code when present
    create unique_index(:places, [:code], where: "code IS NOT NULL",
           name: :places_code_unique_index)

    # GIN trigram indexes on normalized columns for fast fuzzy search
    execute """
    CREATE INDEX places_canonical_norm_gin_trgm_index ON places
    USING GIN (canonical_norm gin_trgm_ops)
    """

    execute """
    CREATE INDEX place_aliases_alias_norm_gin_trgm_index ON place_aliases
    USING GIN (alias_norm gin_trgm_ops)
    """

    # Regular indexes for common queries
    create index(:places, [:kind])
    create index(:places, [:popularity])
    create index(:place_aliases, [:place_id])
    create index(:place_aliases, [:priority])

    # Composite indexes for performance
    create index(:places, [:kind, :popularity])
    create index(:place_aliases, [:place_id, :priority])

    # Spatial index for geographic queries
    execute """
    CREATE INDEX places_location_index ON places USING GIST (
      point(longitude, latitude)
    )
    """
  end

  def down do
    drop table(:place_aliases)
    drop table(:places)

    # Drop immutable function
    execute "DROP FUNCTION IF EXISTS immutable_unaccent(text)"

    # Note: We don't drop extensions as they might be used by other parts of the system
  end
end
