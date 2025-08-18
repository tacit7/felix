defmodule RouteWiseApi.Repo.Migrations.AddTripTypeToTrips do
  use Ecto.Migration

  def change do
    alter table(:trips) do
      add :trip_type, :string, default: "road-trip"
    end

    # Add index for trip_type for faster filtering
    create index(:trips, [:trip_type])
  end
end
