defmodule RouteWiseApi.Repo.Migrations.AddWikiImageToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      add :wiki_image, :string
    end
  end
end
