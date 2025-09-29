defmodule RouteWiseApi.Repo.Migrations.RenameTripPlacesToTripPois do
  use Ecto.Migration

  def change do
    rename table(:trip_places), to: table(:trip_pois)
  end
end
