defmodule RouteWiseApi.Repo.Migrations.AddSharingToTrips do
  use Ecto.Migration

  def change do
    alter table(:trips) do
      # Sharing configuration
      add :is_shareable, :boolean, default: false
      add :share_token, :string, size: 64
      add :share_expires_at, :utc_datetime
      add :share_permissions, :map, default: %{}
      
      # Collaboration settings
      add :allow_public_edit, :boolean, default: false
      add :require_approval_for_edits, :boolean, default: true
      add :max_collaborators, :integer, default: 10
    end

    # Create unique index on share_token
    create unique_index(:trips, [:share_token])
    
    # Create collaborators table
    create table(:trip_collaborators, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :permission_level, :string, null: false, default: "viewer"
      add :invited_by_id, references(:users, on_delete: :nilify_all)
      add :invited_at, :utc_datetime, null: false
      add :accepted_at, :utc_datetime
      add :last_activity_at, :utc_datetime
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    # Indexes for trip collaborators
    create unique_index(:trip_collaborators, [:trip_id, :user_id])
    create index(:trip_collaborators, [:user_id])
    create index(:trip_collaborators, [:permission_level])
    create index(:trip_collaborators, [:status])
    
    # Create trip activity log table for tracking changes
    create table(:trip_activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :description, :text
      add :changes_data, :map, default: %{}
      add :ip_address, :string
      add :user_agent, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Indexes for activity tracking
    create index(:trip_activities, [:trip_id])
    create index(:trip_activities, [:user_id])
    create index(:trip_activities, [:action])
    create index(:trip_activities, [:inserted_at])
  end
end