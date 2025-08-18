defmodule RouteWiseApi.Repo.Migrations.ConvertPlacesToSerialId do
  use Ecto.Migration

  def up do
    # Step 1: Create new places table with serial ID
    create table(:places_new) do
      add :google_place_id, :string, null: false
      add :name, :string
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
      add :google_data, :map, default: %{}
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # Step 2: Add indexes to new table
    create unique_index(:places_new, [:google_place_id])
    create index(:places_new, [:latitude, :longitude])
    create index(:places_new, [:place_types])
    create index(:places_new, [:rating])
    create index(:places_new, [:cached_at])

    # Step 3: Copy data from old table to new table (if any exists)
    execute """
    INSERT INTO places_new (google_place_id, name, formatted_address, latitude, longitude, 
                           place_types, rating, price_level, phone_number, website, 
                           opening_hours, photos, reviews_count, google_data, cached_at,
                           inserted_at, updated_at)
    SELECT google_place_id, name, formatted_address, latitude, longitude, 
           place_types, rating, price_level, phone_number, website, 
           opening_hours, photos, reviews_count, google_data, cached_at,
           inserted_at, updated_at
    FROM places
    """

    # Step 4: Drop old table and rename new table
    drop table(:places)
    rename table(:places_new), to: table(:places)
  end

  def down do
    # Step 1: Create old places table with binary_id
    create table(:places_old, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :google_place_id, :string, null: false
      add :name, :string
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
      add :google_data, :map, default: %{}
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # Step 2: Add indexes to old table
    create unique_index(:places_old, [:google_place_id])
    create index(:places_old, [:latitude, :longitude])
    create index(:places_old, [:place_types])
    create index(:places_old, [:rating])
    create index(:places_old, [:cached_at])

    # Step 3: Copy data back (Note: This will lose the original UUIDs)
    execute """
    INSERT INTO places_old (id, google_place_id, name, formatted_address, latitude, longitude, 
                           place_types, rating, price_level, phone_number, website, 
                           opening_hours, photos, reviews_count, google_data, cached_at,
                           inserted_at, updated_at)
    SELECT gen_random_uuid(), google_place_id, name, formatted_address, latitude, longitude, 
           place_types, rating, price_level, phone_number, website, 
           opening_hours, photos, reviews_count, google_data, cached_at,
           inserted_at, updated_at
    FROM places
    """

    # Step 4: Drop current table and rename old table
    drop table(:places)
    rename table(:places_old), to: table(:places)
  end
end
