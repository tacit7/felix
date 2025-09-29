defmodule RouteWiseApi.Repo.Migrations.CreateDefaultImages do
  use Ecto.Migration

  def change do
    create table(:default_images) do
      add :category, :string, null: false
      add :image_url, :text, null: false
      add :fallback_url, :text
      add :description, :text
      add :source, :string, default: "unsplash"
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:default_images, [:category])
    create index(:default_images, [:is_active])
    create index(:default_images, [:source])
  end
end
