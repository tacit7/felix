defmodule RouteWiseApi.Repo.Migrations.PopulateSampleCities do
  use Ecto.Migration

  def up do
    # Insert some popular cities for testing the database-first search
    # Insert cities one by one to let Ecto handle ID generation
    execute """
    INSERT INTO cities (id, location_iq_place_id, name, display_name, latitude, longitude, city_type, state, country, country_code, search_count, inserted_at, updated_at) VALUES
    (gen_random_uuid(), '151814', 'San Juan', 'San Juan, Puerto Rico', 18.4655, -66.1057, 'city', 'Puerto Rico', 'Puerto Rico', 'pr', 10, NOW(), NOW())
    ON CONFLICT (location_iq_place_id) DO UPDATE SET
      search_count = cities.search_count + 1,
      updated_at = NOW();
    """
    
    execute """
    INSERT INTO cities (id, location_iq_place_id, name, display_name, latitude, longitude, city_type, state, country, country_code, search_count, inserted_at, updated_at) VALUES
    (gen_random_uuid(), '170976', 'Austin', 'Austin, Texas, United States', 30.2672, -97.7431, 'city', 'Texas', 'United States', 'us', 25, NOW(), NOW())
    ON CONFLICT (location_iq_place_id) DO UPDATE SET
      search_count = cities.search_count + 1,
      updated_at = NOW();
    """
    
    execute """
    INSERT INTO cities (id, location_iq_place_id, name, display_name, latitude, longitude, city_type, state, country, country_code, search_count, inserted_at, updated_at) VALUES
    (gen_random_uuid(), '280184', 'New York', 'New York, New York, United States', 40.7128, -74.0060, 'city', 'New York', 'United States', 'us', 50, NOW(), NOW())
    ON CONFLICT (location_iq_place_id) DO UPDATE SET
      search_count = cities.search_count + 1,
      updated_at = NOW();
    """
  end

  def down do
    execute """
    DELETE FROM cities WHERE location_iq_place_id IN (
      '151814', '170976', '280184', '349859', '420917', 
      '581349', '641289', '752849', '843762', '924851'
    );
    """
  end
end