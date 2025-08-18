defmodule RouteWiseApi.Repo.Migrations.ConvertUsersToSerialId do
  use Ecto.Migration

  def up do
    # Step 1: Create new users table with serial ID
    create table(:users_new) do
      add :username, :string, null: false
      add :password_hash, :string
      add :email, :string
      add :google_id, :string
      add :full_name, :string
      add :avatar, :string
      add :provider, :string, default: "local"

      timestamps(type: :utc_datetime)
    end

    # Step 2: Add unique constraints to new table
    create unique_index(:users_new, [:username])
    create unique_index(:users_new, [:email])
    create unique_index(:users_new, [:google_id])

    # Step 3: Copy data from old table to new table (if any exists)
    execute """
    INSERT INTO users_new (username, password_hash, email, google_id, full_name, avatar, provider, inserted_at, updated_at)
    SELECT username, password_hash, email, google_id, full_name, avatar, provider, inserted_at, updated_at
    FROM users
    """

    # Step 4: Drop old table and rename new table
    drop table(:users)
    rename table(:users_new), to: table(:users)
  end

  def down do
    # Step 1: Create old users table with binary_id
    create table(:users_old, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :password_hash, :string
      add :email, :string
      add :google_id, :string
      add :full_name, :string
      add :avatar, :string
      add :provider, :string, default: "local"

      timestamps(type: :utc_datetime)
    end

    # Step 2: Add unique constraints to old table
    create unique_index(:users_old, [:username])
    create unique_index(:users_old, [:email])
    create unique_index(:users_old, [:google_id])

    # Step 3: Copy data back (Note: This will lose the original UUIDs)
    execute """
    INSERT INTO users_old (id, username, password_hash, email, google_id, full_name, avatar, provider, inserted_at, updated_at)
    SELECT gen_random_uuid(), username, password_hash, email, google_id, full_name, avatar, provider, inserted_at, updated_at
    FROM users
    """

    # Step 4: Drop current table and rename old table
    drop table(:users)
    rename table(:users_old), to: table(:users)
  end
end
