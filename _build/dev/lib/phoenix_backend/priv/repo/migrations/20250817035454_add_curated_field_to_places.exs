defmodule RouteWiseApi.Repo.Migrations.AddCuratedFieldToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      add :curated, :boolean, default: false, null: false
    end

    create index(:places, [:curated])

    # Update existing places to mark curated ones
    # Places with manual descriptions, tips, or high popularity scores are curated
    execute """
    UPDATE places 
    SET curated = true 
    WHERE 
      description IS NOT NULL 
      OR (tips IS NOT NULL AND array_length(tips, 1) > 0)
      OR best_time_to_visit IS NOT NULL
      OR accessibility IS NOT NULL 
      OR entry_fee IS NOT NULL
      OR popularity_score > 50;
    """, ""
  end
end
