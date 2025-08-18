defmodule RouteWiseApi.Repo.Migrations.RemoveNycTestPois do
  use Ecto.Migration

  def up do
    # Remove the NYC test POIs from database
    execute "DELETE FROM pois WHERE name IN ('Central Park', 'Times Square', 'Joe''s Pizza')"
    execute "DELETE FROM pois WHERE address LIKE '%New York, NY%'"
    execute "DELETE FROM pois WHERE latitude BETWEEN 40.7 AND 40.8 AND longitude BETWEEN -74.0 AND -73.9"
  end

  def down do
    # Recreate the test POIs if needed (though we don't want to in production)
    execute """
      INSERT INTO pois (name, description, category, rating, address, latitude, longitude, inserted_at, updated_at) VALUES
      ('Central Park', 'Large urban park in Manhattan', 'attraction', 4.7, 'Central Park, New York, NY', 40.7829, -73.9654, NOW(), NOW()),
      ('Times Square', 'Famous commercial intersection', 'attraction', 4.3, 'Times Square, New York, NY', 40.7580, -73.9855, NOW(), NOW()),
      ('Joe''s Pizza', 'Learn more: en:Joe''s Pizza', 'restaurant', 4.5, '123 Broadway, New York, NY', 40.7614, -73.9776, NOW(), NOW())
    """
  end
end
