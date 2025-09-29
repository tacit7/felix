defmodule RouteWiseApi.Repo.Migrations.RenamePlacesToPois do
  use Ecto.Migration

  def up do
    # Drop the existing empty pois table first
    drop table(:pois)

    # Rename the places table to pois
    rename table(:places), to: table(:pois)

    # Update foreign key references in other tables

    # Update places_nearby table (only table with actual foreign keys to places)
    execute "ALTER TABLE places_nearby DROP CONSTRAINT IF EXISTS places_nearby_place_id_fkey"
    rename table(:places_nearby), :place_id, to: :poi_id
    execute "ALTER TABLE places_nearby ADD CONSTRAINT places_nearby_poi_id_fkey FOREIGN KEY (poi_id) REFERENCES pois(id)"
  end

  def down do
    # Reverse the changes

    # Revert places_nearby table
    execute "ALTER TABLE places_nearby DROP CONSTRAINT IF EXISTS places_nearby_poi_id_fkey"
    rename table(:places_nearby), :poi_id, to: :place_id
    execute "ALTER TABLE places_nearby ADD CONSTRAINT places_nearby_place_id_fkey FOREIGN KEY (place_id) REFERENCES places(id)"

    # Rename the table back
    rename table(:pois), to: table(:places)

    # Recreate the old empty pois table (if needed for rollback)
    create table(:pois) do
      add :id, :bigserial, primary_key: true
      add :poi_type, :string
      add :name, :string
      add :latitude, :decimal
      add :longitude, :decimal
      add :description, :text
      timestamps()
    end
  end
end