defmodule RouteWiseApi.Repo.Migrations.RenameCitiesToLocations do
  use Ecto.Migration

  def up do
    # Step 1: Add location_type field to existing cities table
    alter table(:cities) do
      add :location_type, :string, null: false, default: "city"
    end

    # Step 2: Update existing records based on city_type
    execute """
    UPDATE cities
    SET location_type = CASE
      WHEN city_type ILIKE '%park%' THEN 'park'
      WHEN city_type ILIKE '%region%' THEN 'region'
      WHEN city_type ILIKE '%country%' THEN 'country'
      WHEN city_type ILIKE '%state%' THEN 'state'
      WHEN city_type ILIKE '%province%' THEN 'province'
      ELSE 'city'
    END
    """

    # Step 3: Rename the table
    rename table(:cities), to: table(:locations)

    # Step 4: Add index for the new location_type field
    create index(:locations, [:location_type])
  end

  def down do
    # Step 1: Rename table back
    rename table(:locations), to: table(:cities)

    # Step 2: Remove the location_type field
    alter table(:cities) do
      remove :location_type
    end
  end
end
