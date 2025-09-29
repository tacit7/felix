defmodule RouteWiseApi.Repo.Migrations.AddDefaultImageToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      add :default_image_id, references(:default_images, on_delete: :nilify_all)
    end

    create index(:places, [:default_image_id])
  end
end
