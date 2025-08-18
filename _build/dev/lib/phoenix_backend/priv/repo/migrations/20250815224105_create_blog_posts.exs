defmodule RouteWiseApi.Repo.Migrations.CreateBlogPosts do
  use Ecto.Migration

  def change do
    create table(:blog_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text, null: false
      add :excerpt, :text
      add :featured_image, :string
      add :author, :string, default: "RouteWise Team"
      add :published, :boolean, default: false
      add :published_at, :utc_datetime
      add :meta_description, :string
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_posts, [:slug])
    create index(:blog_posts, [:published])
    create index(:blog_posts, [:published_at])
    create index(:blog_posts, [:tags], using: :gin)
  end
end
