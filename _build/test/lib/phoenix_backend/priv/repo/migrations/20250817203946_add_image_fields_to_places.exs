defmodule RouteWiseApi.Repo.Migrations.AddImageFieldsToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      # Image caching status
      add :image_data, :map, null: true
      
      # Primary cached image paths
      add :cached_image_original, :string, null: true
      add :cached_image_thumb, :string, null: true  
      add :cached_image_medium, :string, null: true
      add :cached_image_large, :string, null: true
      add :cached_image_xlarge, :string, null: true
      
      # Image processing metadata
      add :images_cached_at, :utc_datetime, null: true
      add :image_processing_status, :string, null: true
      add :image_processing_error, :text, null: true
    end

    # Add index for finding places without cached images
    create index(:places, [:images_cached_at])
    create index(:places, [:image_processing_status])
  end
end