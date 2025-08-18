defmodule RouteWiseApi.Repo.Migrations.AddTripadvisorUrlToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      add :tripadvisor_url, :string
    end

    create index(:places, [:tripadvisor_url])
  end
end
