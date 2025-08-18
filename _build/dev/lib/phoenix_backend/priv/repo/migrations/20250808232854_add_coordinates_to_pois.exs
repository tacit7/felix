defmodule RouteWiseApi.Repo.Migrations.AddCoordinatesToPois do
  use Ecto.Migration

  def change do
    alter table(:pois) do
      add :latitude, :float
      add :longitude, :float
    end

    # Update existing POIs with their coordinates (from the data we created earlier)
    execute "UPDATE pois SET latitude = 40.7829, longitude = -73.9654 WHERE name = 'Central Park'"
    execute "UPDATE pois SET latitude = 40.7580, longitude = -73.9855 WHERE name = 'Times Square'"
    execute "UPDATE pois SET latitude = 40.7614, longitude = -73.9776 WHERE name = 'Joe''s Pizza'"

    # Now make them not null
    alter table(:pois) do
      modify :latitude, :float, null: false
      modify :longitude, :float, null: false
    end

    # Add index for spatial queries
    create index(:pois, [:latitude, :longitude])
  end
end
