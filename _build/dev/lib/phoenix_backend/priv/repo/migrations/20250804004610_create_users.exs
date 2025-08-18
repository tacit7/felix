defmodule RouteWiseApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
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

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
    create unique_index(:users, [:google_id])
  end
end
