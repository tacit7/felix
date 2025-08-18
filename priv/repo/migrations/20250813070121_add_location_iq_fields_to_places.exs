defmodule RouteWiseApi.Repo.Migrations.AddLocationIqFieldsToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      add :location_iq_place_id, :string
      add :location_iq_data, :map
    end

    create_if_not_exists index(:places, [:location_iq_place_id])
    create_if_not_exists unique_index(:places, [:location_iq_place_id], where: "location_iq_place_id IS NOT NULL")
  end
end
