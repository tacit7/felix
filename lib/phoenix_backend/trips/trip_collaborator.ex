defmodule RouteWiseApi.Trips.TripCollaborator do
  use Ecto.Schema
  import Ecto.Changeset

  alias RouteWiseApi.Accounts.User
  alias RouteWiseApi.Trips.Trip

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @permission_levels ["viewer", "editor", "admin"]
  @statuses ["pending", "accepted", "rejected", "removed"]

  schema "trip_collaborators" do
    field :permission_level, :string, default: "viewer"
    field :invited_at, :utc_datetime
    field :accepted_at, :utc_datetime
    field :last_activity_at, :utc_datetime
    field :status, :string, default: "pending"

    belongs_to :trip, Trip
    belongs_to :user, User
    belongs_to :invited_by, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a trip collaborator invitation.
  """
  def invitation_changeset(collaborator, attrs) do
    collaborator
    |> cast(attrs, [:trip_id, :user_id, :invited_by_id, :permission_level])
    |> validate_required([:trip_id, :user_id, :invited_by_id, :permission_level])
    |> validate_inclusion(:permission_level, @permission_levels)
    |> put_change(:invited_at, DateTime.utc_now())
    |> put_change(:status, "pending")
    |> unique_constraint([:trip_id, :user_id])
    |> foreign_key_constraint(:trip_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:invited_by_id)
  end

  @doc """
  Changeset for accepting/rejecting an invitation.
  """
  def response_changeset(collaborator, status) when status in ["accepted", "rejected"] do
    collaborator
    |> change()
    |> put_change(:status, status)
    |> put_change(:accepted_at, if(status == "accepted", do: DateTime.utc_now(), else: nil))
    |> put_change(:last_activity_at, DateTime.utc_now())
  end

  @doc """
  Changeset for updating permission level.
  """
  def permission_changeset(collaborator, attrs) do
    collaborator
    |> cast(attrs, [:permission_level])
    |> validate_required([:permission_level])
    |> validate_inclusion(:permission_level, @permission_levels)
    |> put_change(:last_activity_at, DateTime.utc_now())
  end

  @doc """
  Update last activity timestamp.
  """
  def activity_changeset(collaborator) do
    collaborator
    |> change()
    |> put_change(:last_activity_at, DateTime.utc_now())
  end

  @doc """
  Get valid permission levels.
  """
  def permission_levels, do: @permission_levels

  @doc """
  Get valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  Check if collaborator can edit trip.
  """
  def can_edit?(%__MODULE__{permission_level: level, status: "accepted"}) 
    when level in ["editor", "admin"], do: true
  def can_edit?(_), do: false

  @doc """
  Check if collaborator can manage other collaborators.
  """
  def can_manage_collaborators?(%__MODULE__{permission_level: "admin", status: "accepted"}), do: true
  def can_manage_collaborators?(_), do: false

  @doc """
  Check if collaborator can view trip.
  """
  def can_view?(%__MODULE__{status: "accepted"}), do: true
  def can_view?(_), do: false
end