defmodule RouteWiseApi.Repo.Migrations.CreateTravelNewsArticles do
  use Ecto.Migration

  def change do
    create table(:travel_news_articles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :link, :string, null: false
      add :description, :text
      add :source, :string, null: false
      add :subjects, {:array, :string}, default: []
      add :image, :string
      add :published_at, :utc_datetime, null: false
      add :generated_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:travel_news_articles, [:link])
    create index(:travel_news_articles, [:published_at])
    create index(:travel_news_articles, [:source])
    create index(:travel_news_articles, [:generated_at])
  end
end
