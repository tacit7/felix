defmodule RouteWiseApi.Repo.Migrations.AddGeospatialToPlaces do
  use Ecto.Migration

  def up do
    # Enable PostGIS extension if not already enabled
    execute "CREATE EXTENSION IF NOT EXISTS postgis;"
    
    # Add geometry column (PostGIS point type)
    execute "SELECT AddGeometryColumn('places', 'location', 4326, 'POINT', 2);"
    
    # Create spatial index for fast nearby searches
    execute "CREATE INDEX places_location_gist_idx ON places USING GIST (location);"
    
    # Update existing records to populate the geometry column
    execute """
    UPDATE places 
    SET location = ST_SetSRID(ST_MakePoint(CAST(longitude AS double precision), CAST(latitude AS double precision)), 4326) 
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
    """
    
    # Add trigger to auto-update geometry when lat/lng changes
    execute """
    CREATE OR REPLACE FUNCTION update_places_location() RETURNS TRIGGER AS $$
    BEGIN
      IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location = ST_SetSRID(ST_MakePoint(CAST(NEW.longitude AS double precision), CAST(NEW.latitude AS double precision)), 4326);
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    execute """
    CREATE TRIGGER places_location_trigger
    BEFORE INSERT OR UPDATE ON places
    FOR EACH ROW EXECUTE FUNCTION update_places_location();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS places_location_trigger ON places;"
    execute "DROP FUNCTION IF EXISTS update_places_location();"
    execute "DROP INDEX IF EXISTS places_location_gist_idx;"
    execute "SELECT DropGeometryColumn('places', 'location');"
  end
end