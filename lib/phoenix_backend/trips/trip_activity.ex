defmodule RouteWiseApi.Trips.TripActivity do
  use Ecto.Schema
  import Ecto.Changeset

  alias RouteWiseApi.Accounts.User
  alias RouteWiseApi.Trips.Trip

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @actions [
    "created", "updated", "deleted", "shared", "unshared",
    "collaborator_added", "collaborator_removed", "collaborator_permission_changed",
    "poi_added", "poi_removed", "poi_updated", "day_added", "day_removed", "day_updated",
    "route_updated", "settings_updated"
  ]

  schema "trip_activities" do
    field :action, :string
    field :description, :string
    field :changes_data, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :trip, Trip
    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating a trip activity log entry.
  """
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:trip_id, :user_id, :action, :description, :changes_data, :ip_address, :user_agent])
    |> validate_required([:trip_id, :action])
    |> validate_inclusion(:action, @actions)
    |> validate_length(:description, max: 500)
    |> foreign_key_constraint(:trip_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Create activity log entry for trip creation.
  """
  def log_created(trip_id, user_id, opts \\ []) do
    %{
      trip_id: trip_id,
      user_id: user_id,
      action: "created",
      description: "Trip created",
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    }
  end

  @doc """
  Create activity log entry for trip updates.
  """
  def log_updated(trip_id, user_id, changes, opts \\ []) do
    description = generate_update_description(changes)
    
    %{
      trip_id: trip_id,
      user_id: user_id,
      action: "updated",
      description: description,
      changes_data: %{changes: changes},
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    }
  end

  @doc """
  Create activity log entry for sharing.
  """
  def log_shared(trip_id, user_id, share_settings, opts \\ []) do
    %{
      trip_id: trip_id,
      user_id: user_id,
      action: "shared",
      description: "Trip shared with link",
      changes_data: %{share_settings: share_settings},
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    }
  end

  @doc """
  Create activity log entry for collaborator addition.
  """
  def log_collaborator_added(trip_id, user_id, collaborator_email, permission_level, opts \\ []) do
    %{
      trip_id: trip_id,
      user_id: user_id,
      action: "collaborator_added",
      description: "Added #{collaborator_email} as #{permission_level}",
      changes_data: %{
        collaborator_email: collaborator_email,
        permission_level: permission_level
      },
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    }
  end

  @doc """
  Create activity log entry for POI operations.
  """
  def log_poi_action(trip_id, user_id, action, poi_name, opts \\ []) 
    when action in ["poi_added", "poi_removed", "poi_updated"] do
    
    description = case action do
      "poi_added" -> "Added POI: #{poi_name}"
      "poi_removed" -> "Removed POI: #{poi_name}"
      "poi_updated" -> "Updated POI: #{poi_name}"
    end

    %{
      trip_id: trip_id,
      user_id: user_id,
      action: action,
      description: description,
      changes_data: %{poi_name: poi_name},
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    }
  end

  @doc """
  Get valid actions.
  """
  def actions, do: @actions

  # Private helpers

  defp generate_update_description(changes) when is_map(changes) do
    field_names = Map.keys(changes)
    |> Enum.reject(&(&1 in ["updated_at", "last_modified_by_user_at"]))
    |> Enum.map(&humanize_field/1)
    |> Enum.join(", ")

    case field_names do
      "" -> "Trip updated"
      fields -> "Updated #{fields}"
    end
  end

  defp humanize_field("title"), do: "title"
  defp humanize_field("start_date"), do: "start date"
  defp humanize_field("end_date"), do: "end date"
  defp humanize_field("start_location"), do: "start location"
  defp humanize_field("end_location"), do: "end location"
  defp humanize_field("days"), do: "itinerary"
  defp humanize_field("trip_tags"), do: "tags"
  defp humanize_field("difficulty_level"), do: "difficulty"
  defp humanize_field("is_public"), do: "visibility"
  defp humanize_field(field), do: String.replace(field, "_", " ")
end