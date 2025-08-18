defmodule RouteWiseApi.Repo.Migrations.AddEnrichedFieldsToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      # Hidden gem classification
      add :hidden_gem, :boolean, default: false
      add :hidden_gem_reason, :text
      
      # Overrated classification  
      add :overrated, :boolean, default: false
      add :overrated_reason, :text
      
      # TripAdvisor specific data
      add :tripadvisor_rating, :decimal, precision: 3, scale: 2
      add :tripadvisor_review_count, :integer
      
      # Practical visit information
      add :entry_fee, :text
      add :best_time_to_visit, :text
      add :accessibility, :text
      add :duration_suggested, :text
      
      # Relationships and metadata
      add :related_places, {:array, :text}, default: []
      add :local_name, :text
      add :wikidata_id, :text
    end
    
    # Add indexes for commonly queried fields
    create index(:places, [:hidden_gem])
    create index(:places, [:overrated]) 
    create index(:places, [:tripadvisor_rating])
    create index(:places, [:best_time_to_visit])
  end
end
