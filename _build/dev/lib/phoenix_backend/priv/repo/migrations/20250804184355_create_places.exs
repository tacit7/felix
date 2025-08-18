defmodule RouteWiseApi.Repo.Migrations.CreatePlaces do
  use Ecto.Migration

  def change do
    create table(:places, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :google_place_id, :string, null: false
      add :name, :string, null: false
      add :formatted_address, :string
      add :latitude, :decimal, precision: 10, scale: 6
      add :longitude, :decimal, precision: 10, scale: 6
      add :place_types, {:array, :string}, default: []
      add :rating, :decimal, precision: 3, scale: 2
      add :price_level, :integer
      add :phone_number, :string
      add :website, :string
      add :opening_hours, :map
      add :photos, {:array, :map}, default: []
      add :reviews_count, :integer, default: 0
      add :google_data, :map
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:places, [:google_place_id])
    create index(:places, [:latitude, :longitude])
    create index(:places, [:place_types])
    create index(:places, [:rating])
    create index(:places, [:cached_at])
  end
end
