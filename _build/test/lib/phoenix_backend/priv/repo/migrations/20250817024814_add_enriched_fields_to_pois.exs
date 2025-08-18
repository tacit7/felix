defmodule RouteWiseApi.Repo.Migrations.AddEnrichedFieldsToPois do
  use Ecto.Migration

  def change do
    alter table(:pois) do
      add :tips, {:array, :text}, default: []
      add :best_time_to_visit, :text
      add :duration_suggested, :text
      add :accessibility, :text
      add :entry_fee, :text
    end
  end
end
