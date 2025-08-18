defmodule RouteWiseApi.Repo.Migrations.CreateCities do
  use Ecto.Migration

  def change do
    create table(:cities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :location_iq_place_id, :string, null: false
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :latitude, :decimal, precision: 10, scale: 8, null: false
      add :longitude, :decimal, precision: 11, scale: 8, null: false
      add :city_type, :string
      add :state, :string
      add :country, :string, null: false
      add :country_code, :string, null: false
      add :search_count, :integer, default: 0
      add :last_searched_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:cities, [:location_iq_place_id])
    create index(:cities, [:name])
    create index(:cities, [:country_code])
    create index(:cities, [:search_count])
    create index(:cities, [:last_searched_at])
  end
end
