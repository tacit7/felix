defmodule RouteWiseApi.Repo.Migrations.AddTipsToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      add :tips, {:array, :text}, default: []
    end
  end
end
