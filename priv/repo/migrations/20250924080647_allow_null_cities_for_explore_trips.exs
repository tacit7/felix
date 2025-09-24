defmodule RouteWiseApi.Repo.Migrations.AllowNullCitiesForExploreTrips do
  use Ecto.Migration

  def up do
    # Allow NULL values for start_city and end_city to support explore trips
    alter table(:trips) do
      modify :start_city, :string, null: true
      modify :end_city, :string, null: true
    end
  end

  def down do
    # Revert back to NOT NULL constraints (but this will fail if there are explore trips with NULL cities)
    alter table(:trips) do
      modify :start_city, :string, null: false
      modify :end_city, :string, null: false
    end
  end
end