defmodule RouteWiseApi.Repo.Migrations.CreateGoogleApiUsage do
  use Ecto.Migration

  def change do
    create table(:google_api_usage) do
      add :usage_date, :date, null: false
      add :endpoint_type, :string, null: false
      add :call_count, :integer, null: false, default: 0
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    # Unique constraint per date/endpoint combination
    create unique_index(:google_api_usage, [:usage_date, :endpoint_type])
    
    # Index for fast date queries
    create index(:google_api_usage, [:usage_date])
    create index(:google_api_usage, [:endpoint_type])
  end
end
