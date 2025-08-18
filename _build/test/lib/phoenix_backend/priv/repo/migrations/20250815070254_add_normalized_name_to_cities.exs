defmodule RouteWiseApi.Repo.Migrations.AddNormalizedNameToCities do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :normalized_name, :string
    end

    create index(:cities, [:normalized_name])
  end
end