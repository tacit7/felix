defmodule RouteWiseApiWeb.TripSharingController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Trips
  alias RouteWiseApi.Trips.{Trip, TripCollaborator, TripActivity}
  alias RouteWiseApi.Repo

  action_fallback RouteWiseApiWeb.FallbackController

  @doc """
  POST /api/trips/:id/share
  Enable sharing for a trip with customizable permissions.
  """
  def share_trip(conn, %{"id" => trip_id, "sharing" => sharing_params}) do
    user_id = get_current_user_id(conn)
    
    with {:ok, trip} <- get_user_trip(trip_id, user_id),
         {:ok, updated_trip} <- enable_sharing(trip, sharing_params, user_id, conn) do
      
      json(conn, %{
        success: true,
        data: %{
          share_url: Trip.share_url(updated_trip),
          share_token: updated_trip.share_token,
          expires_at: updated_trip.share_expires_at,
          permissions: updated_trip.share_permissions,
          settings: %{
            allow_public_edit: updated_trip.allow_public_edit,
            require_approval_for_edits: updated_trip.require_approval_for_edits,
            max_collaborators: updated_trip.max_collaborators
          }
        }
      })
    end
  end

  def share_trip(conn, %{"id" => trip_id}) do
    # Default sharing settings
    share_trip(conn, %{"id" => trip_id, "sharing" => %{}})
  end

  @doc """
  DELETE /api/trips/:id/share
  Disable sharing for a trip.
  """
  def unshare_trip(conn, %{"id" => trip_id}) do
    user_id = get_current_user_id(conn)
    
    with {:ok, trip} <- get_user_trip(trip_id, user_id),
         {:ok, updated_trip} <- disable_sharing(trip, user_id, conn) do
      
      json(conn, %{
        success: true,
        data: %{
          message: "Trip sharing disabled",
          is_shareable: false
        }
      })
    end
  end

  @doc """
  GET /api/shared/trips/:share_token
  View a shared trip by its share token (public endpoint).
  """
  def view_shared_trip(conn, %{"share_token" => share_token}) do
    with {:ok, trip} <- get_trip_by_share_token(share_token),
         :ok <- validate_sharing_access(trip) do
      
      # Preload necessary associations for shared view
      trip = Repo.preload(trip, [:user, :collaborators])
      
      json(conn, %{
        success: true,
        data: %{
          trip: format_shared_trip(trip),
          permissions: trip.share_permissions,
          owner: %{
            id: trip.user.id,
            username: trip.user.username,
            full_name: trip.user.full_name
          },
          collaborators: Enum.map(trip.collaborators, &format_collaborator/1),
          sharing_info: %{
            is_shareable: trip.is_shareable,
            expires_at: trip.share_expires_at,
            allow_public_edit: trip.allow_public_edit
          }
        }
      })
    end
  end

  @doc """
  POST /api/trips/:id/collaborators
  Add a collaborator to a trip.
  """
  def add_collaborator(conn, %{"id" => trip_id, "collaborator" => collaborator_params}) do
    user_id = get_current_user_id(conn)
    
    with {:ok, trip} <- get_user_trip(trip_id, user_id),
         {:ok, collaborator} <- invite_collaborator(trip, collaborator_params, user_id, conn) do
      
      json(conn, %{
        success: true,
        data: %{
          collaborator: format_collaborator(collaborator),
          message: "Collaborator invitation sent"
        }
      })
    end
  end

  @doc """
  PUT /api/trips/:id/collaborators/:collaborator_id
  Update collaborator permissions.
  """
  def update_collaborator(conn, %{"id" => trip_id, "collaborator_id" => collab_id, "collaborator" => params}) do
    user_id = get_current_user_id(conn)
    
    with {:ok, trip} <- get_user_trip(trip_id, user_id),
         {:ok, collaborator} <- get_trip_collaborator(trip.id, collab_id),
         {:ok, updated_collaborator} <- update_collaborator_permissions(collaborator, params) do
      
      json(conn, %{
        success: true,
        data: %{
          collaborator: format_collaborator(updated_collaborator),
          message: "Collaborator permissions updated"
        }
      })
    end
  end

  @doc """
  DELETE /api/trips/:id/collaborators/:collaborator_id
  Remove a collaborator from a trip.
  """
  def remove_collaborator(conn, %{"id" => trip_id, "collaborator_id" => collab_id}) do
    user_id = get_current_user_id(conn)
    
    with {:ok, trip} <- get_user_trip(trip_id, user_id),
         {:ok, collaborator} <- get_trip_collaborator(trip.id, collab_id),
         {:ok, _} <- remove_trip_collaborator(collaborator, user_id, conn) do
      
      json(conn, %{
        success: true,
        data: %{
          message: "Collaborator removed"
        }
      })
    end
  end

  @doc """
  GET /api/trips/:id/activity
  Get activity log for a trip.
  """
  def trip_activity(conn, %{"id" => trip_id}) do
    user_id = get_current_user_id(conn)
    
    with {:ok, trip} <- get_user_trip(trip_id, user_id),
         activities <- get_trip_activities(trip.id) do
      
      json(conn, %{
        success: true,
        data: %{
          activities: Enum.map(activities, &format_activity/1),
          trip_id: trip.id
        }
      })
    end
  end

  # Private helper functions

  defp get_current_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> user_id
      _ -> nil
    end
  end

  defp get_user_trip(trip_id, user_id) do
    case Trips.get_trip(trip_id) do
      %Trip{user_id: ^user_id} = trip -> {:ok, trip}
      %Trip{} -> {:error, :forbidden}
      nil -> {:error, :not_found}
    end
  end

  defp get_trip_by_share_token(share_token) do
    case Trips.get_trip_by_share_token(share_token) do
      %Trip{} = trip -> {:ok, trip}
      nil -> {:error, :not_found}
    end
  end

  defp validate_sharing_access(%Trip{} = trip) do
    if Trip.sharing_valid?(trip) do
      :ok
    else
      {:error, :sharing_expired}
    end
  end

  defp enable_sharing(trip, params, user_id, conn) do
    changeset = Trip.sharing_changeset(trip, params)
    
    case Repo.update(changeset) do
      {:ok, updated_trip} ->
        log_activity(updated_trip.id, user_id, "shared", "Trip sharing enabled", conn)
        {:ok, updated_trip}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp disable_sharing(trip, user_id, conn) do
    changeset = Trip.unshare_changeset(trip)
    
    case Repo.update(changeset) do
      {:ok, updated_trip} ->
        log_activity(updated_trip.id, user_id, "unshared", "Trip sharing disabled", conn)
        {:ok, updated_trip}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp invite_collaborator(trip, params, invited_by_id, conn) do
    # Find user by email
    case RouteWiseApi.Accounts.get_user_by_email(params["email"]) do
      nil ->
        {:error, :user_not_found}
      user ->
        collab_attrs = %{
          trip_id: trip.id,
          user_id: user.id,
          invited_by_id: invited_by_id,
          permission_level: params["permission_level"] || "viewer"
        }
        
        changeset = TripCollaborator.invitation_changeset(%TripCollaborator{}, collab_attrs)
        
        case Repo.insert(changeset) do
          {:ok, collaborator} ->
            collaborator = Repo.preload(collaborator, [:user])
            log_activity(trip.id, invited_by_id, "collaborator_added", 
                        "Added #{user.email} as #{collaborator.permission_level}", conn)
            {:ok, collaborator}
          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  defp get_trip_collaborator(trip_id, collaborator_id) do
    case Repo.get_by(TripCollaborator, trip_id: trip_id, id: collaborator_id) do
      %TripCollaborator{} = collaborator -> {:ok, collaborator}
      nil -> {:error, :not_found}
    end
  end

  defp update_collaborator_permissions(collaborator, params) do
    changeset = TripCollaborator.permission_changeset(collaborator, params)
    Repo.update(changeset)
  end

  defp remove_trip_collaborator(collaborator, user_id, conn) do
    case Repo.delete(collaborator) do
      {:ok, deleted_collaborator} ->
        log_activity(collaborator.trip_id, user_id, "collaborator_removed", 
                    "Removed collaborator", conn)
        {:ok, deleted_collaborator}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp get_trip_activities(trip_id) do
    import Ecto.Query
    
    from(a in TripActivity,
      where: a.trip_id == ^trip_id,
      order_by: [desc: a.inserted_at],
      limit: 50,
      preload: [:user]
    )
    |> Repo.all()
  end

  defp log_activity(trip_id, user_id, action, description, conn) do
    activity_attrs = %{
      trip_id: trip_id,
      user_id: user_id,
      action: action,
      description: description,
      ip_address: get_client_ip(conn),
      user_agent: get_req_header(conn, "user-agent") |> List.first()
    }
    
    changeset = TripActivity.changeset(%TripActivity{}, activity_attrs)
    Repo.insert(changeset)
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> String.split(ip, ",") |> List.first() |> String.trim()
      [] -> 
        case conn.remote_ip do
          ip when is_tuple(ip) -> :inet.ntoa(ip) |> to_string()
          ip -> to_string(ip)
        end
    end
  end

  # Formatting functions

  defp format_shared_trip(trip) do
    %{
      id: trip.id,
      title: trip.title,
      start_city: trip.start_city,
      end_city: trip.end_city,
      start_date: trip.start_date,
      end_date: trip.end_date,
      start_location: trip.start_location,
      end_location: trip.end_location,
      days: trip.days,
      trip_type: trip.trip_type,
      difficulty_level: trip.difficulty_level,
      trip_tags: trip.trip_tags,
      total_distance_km: trip.total_distance_km,
      estimated_cost: trip.estimated_cost,
      status: trip.status,
      created_at: trip.inserted_at,
      updated_at: trip.updated_at
    }
  end

  defp format_collaborator(collaborator) do
    %{
      id: collaborator.id,
      user: %{
        id: collaborator.user.id,
        username: collaborator.user.username,
        full_name: collaborator.user.full_name,
        email: collaborator.user.email
      },
      permission_level: collaborator.permission_level,
      status: collaborator.status,
      invited_at: collaborator.invited_at,
      accepted_at: collaborator.accepted_at,
      last_activity_at: collaborator.last_activity_at
    }
  end

  defp format_activity(activity) do
    %{
      id: activity.id,
      action: activity.action,
      description: activity.description,
      user: if(activity.user, do: %{
        username: activity.user.username,
        full_name: activity.user.full_name
      }, else: nil),
      changes_data: activity.changes_data,
      timestamp: activity.inserted_at
    }
  end
end