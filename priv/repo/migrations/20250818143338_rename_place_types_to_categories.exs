defmodule RouteWiseApi.Repo.Migrations.RenamePlaceTypesToCategories do
  use Ecto.Migration

  def change do
    rename table(:places), :place_types, to: :categories
  end
end
