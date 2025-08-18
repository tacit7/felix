defmodule RouteWiseApi.Trips.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  alias RouteWiseApi.Accounts.User
  alias RouteWiseApi.Trips.{TripCollaborator, TripActivity}

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "trips" do
    # Original fields
    field :title, :string
    field :start_city, :string
    field :end_city, :string
    field :trip_type, :string, default: "road-trip"
    field :checkpoints, :map
    field :route_data, :map
    field :pois_data, :map
    field :is_public, :boolean, default: false

    # Enhanced trip planning fields
    field :start_date, :date
    field :end_date, :date
    field :start_location, :map  # {name, lat, lng, place_id}
    field :end_location, :map    # {name, lat, lng, place_id}
    
    # Core itinerary structure - JSON with comprehensive activity support
    field :days, :map, default: %{"days" => []}
    
    # Enhanced metadata
    field :total_distance_km, :decimal
    field :estimated_cost, :decimal
    field :difficulty_level, :string, default: "moderate"  # easy, moderate, challenging
    field :trip_tags, {:array, :string}, default: []  # [\"family-friendly\", \"budget\", \"adventure\"]
    field :weather_requirements, :map  # Weather preferences/restrictions
    field :packing_list, {:array, :string}, default: []
    
    # Status tracking
    field :status, :string, default: "planning"  # planning, confirmed, in_progress, completed, cancelled
    field :last_modified_by_user_at, :utc_datetime
    
    # Sharing and collaboration fields
    field :is_shareable, :boolean, default: false
    field :share_token, :string
    field :share_expires_at, :utc_datetime
    field :share_permissions, :map, default: %{}
    field :allow_public_edit, :boolean, default: false
    field :require_approval_for_edits, :boolean, default: true
    field :max_collaborators, :integer, default: 10

    belongs_to :user, User
    has_many :collaborators, TripCollaborator, foreign_key: :trip_id
    has_many :activities, TripActivity, foreign_key: :trip_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  A trip changeset for creation and updates.
  """
  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [
      # Original fields
      :title, :start_city, :end_city, :trip_type, :checkpoints, :route_data, 
      :pois_data, :is_public, :user_id,
      # Enhanced fields
      :start_date, :end_date, :start_location, :end_location, :days,
      :total_distance_km, :estimated_cost, :difficulty_level, :trip_tags,
      :weather_requirements, :packing_list, :status, :last_modified_by_user_at,
      # Sharing fields
      :is_shareable, :allow_public_edit, :require_approval_for_edits, :max_collaborators
    ])
    |> validate_required([:title, :start_city, :end_city, :user_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:start_city, min: 1, max: 255)
    |> validate_length(:end_city, min: 1, max: 255)
    |> validate_inclusion(:trip_type, [
      "road-trip", "day-trip", "weekend-getaway", "vacation", "business", 
      "adventure", "cultural", "food-tour", "nature", "urban-exploration", 
      "road", "route", "explore"
    ], message: "must be a valid trip type")
    |> validate_inclusion(:difficulty_level, ["easy", "moderate", "challenging"], 
       message: "must be easy, moderate, or challenging")
    |> validate_inclusion(:status, ["planning", "confirmed", "in_progress", "completed", "cancelled"], 
       message: "must be a valid status")
    |> validate_date_order()
    |> validate_positive_numbers()
    |> validate_trip_tags()
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a Trip struct from trip wizard data with enhanced fields.
  """
  def from_wizard_data(wizard_data, user_id) do
    trip_type = wizard_data["tripType"] || "road-trip"
    
    %{
      # Original fields
      title: generate_trip_title(wizard_data),
      start_city: get_location_name(wizard_data["startLocation"]),
      end_city: get_location_name(wizard_data["endLocation"]),
      trip_type: trip_type,
      checkpoints: format_checkpoints(wizard_data["stops"]),
      route_data: %{},
      pois_data: %{},
      is_public: false,
      user_id: user_id,
      
      # Enhanced fields from wizard data
      start_date: parse_date(wizard_data["startDate"]),
      end_date: parse_date(wizard_data["endDate"]),
      start_location: format_location(wizard_data["startLocation"]),
      end_location: format_location(wizard_data["endLocation"]),
      days: %{"days" => []},  # Will be populated when route is calculated
      difficulty_level: wizard_data["difficulty"] || "moderate",
      trip_tags: format_trip_tags(wizard_data["interests"], wizard_data["tripStyle"]),
      weather_requirements: format_weather_requirements(wizard_data),
      status: "planning",
      last_modified_by_user_at: DateTime.utc_now()
    }
  end

  defp generate_trip_title(wizard_data) do
    start = get_location_name(wizard_data["startLocation"])
    end_location = get_location_name(wizard_data["endLocation"])
    
    case wizard_data["tripType"] do
      "road-trip" -> "Road Trip: #{start} to #{end_location}"
      "flight-based" -> "Flight Trip: #{start} to #{end_location}"
      "combo" -> "Multi-Modal Trip: #{start} to #{end_location}"
      _ -> "Trip: #{start} to #{end_location}"
    end
  end

  defp get_location_name(location) when is_map(location) do
    location["main_text"] || location["description"] || "Unknown Location"
  end
  defp get_location_name(_), do: "Unknown Location"

  defp format_checkpoints(stops) when is_list(stops) do
    %{
      "stops" => Enum.map(stops, fn stop ->
        get_location_name(stop)
      end)
    }
  end
  defp format_checkpoints(_), do: %{"stops" => []}

  # Enhanced wizard data processing helpers

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(_), do: nil

  defp format_location(location) when is_map(location) do
    %{
      "name" => get_location_name(location),
      "lat" => location["lat"] || location["latitude"],
      "lng" => location["lng"] || location["longitude"],
      "place_id" => location["place_id"] || location["placeId"]
    }
  end
  defp format_location(_), do: %{}

  defp format_trip_tags(interests, trip_style) when is_list(interests) do
    interest_tags = interests || []
    style_tags = case trip_style do
      "budget" -> ["budget"]
      "luxury" -> ["luxury"]
      "family" -> ["family-friendly"]
      "adventure" -> ["adventure"]
      "cultural" -> ["cultural"]
      "romantic" -> ["romantic"]
      "solo" -> ["solo"]
      _ -> []
    end
    
    Enum.uniq(interest_tags ++ style_tags)
  end
  defp format_trip_tags(_, _), do: []

  defp format_weather_requirements(wizard_data) do
    %{
      "season_preference" => wizard_data["season"],
      "weather_tolerance" => wizard_data["weatherTolerance"] || "moderate",
      "indoor_backup_needed" => wizard_data["needIndoorBackup"] || false,
      "temperature_preference" => wizard_data["temperaturePreference"]
    }
  end

  # Validation helper functions for enhanced fields

  defp validate_date_order(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && Date.compare(start_date, end_date) == :gt do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
  end

  defp validate_positive_numbers(changeset) do
    changeset
    |> validate_number(:total_distance_km, greater_than: 0, message: "must be positive")
    |> validate_number(:estimated_cost, greater_than: 0, message: "must be positive")
  end

  defp validate_trip_tags(changeset) do
    tags = get_field(changeset, :trip_tags)
    
    if tags && is_list(tags) do
      valid_tags = [
        "family-friendly", "budget", "luxury", "adventure", "cultural", 
        "food-focused", "nature", "urban", "romantic", "solo", "group",
        "accessible", "photography", "historical", "beach", "mountain",
        "desert", "winter", "summer"
      ]
      
      invalid_tags = Enum.reject(tags, &(&1 in valid_tags))
      
      if Enum.empty?(invalid_tags) do
        changeset
      else
        add_error(changeset, :trip_tags, "contains invalid tags: #{Enum.join(invalid_tags, ", ")}")
      end
    else
      changeset
    end
  end

  @doc """
  Activity management helpers for the days JSON field.
  """
  def add_activity_to_day(trip, day_index, activity) do
    days = get_days_list(trip)
    
    updated_days = List.update_at(days, day_index, fn day ->
      activities = Map.get(day, "activities", [])
      Map.put(day, "activities", activities ++ [activity])
    end)
    
    put_in(trip.days["days"], updated_days)
  end

  def update_activity_in_day(trip, day_index, activity_index, updated_activity) do
    days = get_days_list(trip)
    
    updated_days = List.update_at(days, day_index, fn day ->
      activities = Map.get(day, "activities", [])
      updated_activities = List.update_at(activities, activity_index, fn _ -> updated_activity end)
      Map.put(day, "activities", updated_activities)
    end)
    
    put_in(trip.days["days"], updated_days)
  end

  def remove_activity_from_day(trip, day_index, activity_index) do
    days = get_days_list(trip)
    
    updated_days = List.update_at(days, day_index, fn day ->
      activities = Map.get(day, "activities", [])
      updated_activities = List.delete_at(activities, activity_index)
      Map.put(day, "activities", updated_activities)
    end)
    
    put_in(trip.days["days"], updated_days)
  end

  defp get_days_list(trip) do
    case trip.days do
      %{"days" => days} when is_list(days) -> days
      _ -> []
    end
  end

  @doc """
  Generate a secure share token for the trip.
  """
  def generate_share_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc """
  Changeset for enabling sharing on a trip.
  """
  def sharing_changeset(trip, attrs \\ %{}) do
    expires_at = attrs["expires_hours"]
    |> case do
      nil -> DateTime.add(DateTime.utc_now(), 30, :day)  # Default 30 days
      hours when is_integer(hours) -> DateTime.add(DateTime.utc_now(), hours, :hour)
      hours when is_binary(hours) -> 
        case Integer.parse(hours) do
          {h, ""} -> DateTime.add(DateTime.utc_now(), h, :hour)
          _ -> DateTime.add(DateTime.utc_now(), 30, :day)
        end
    end

    trip
    |> cast(attrs, [:allow_public_edit, :require_approval_for_edits, :max_collaborators])
    |> put_change(:is_shareable, true)
    |> put_change(:share_token, generate_share_token())
    |> put_change(:share_expires_at, expires_at)
    |> put_change(:share_permissions, build_share_permissions(attrs))
    |> validate_number(:max_collaborators, greater_than: 0, less_than_or_equal_to: 50)
  end

  @doc """
  Changeset for disabling sharing on a trip.
  """
  def unshare_changeset(trip) do
    trip
    |> change()
    |> put_change(:is_shareable, false)
    |> put_change(:share_token, nil)
    |> put_change(:share_expires_at, nil)
    |> put_change(:share_permissions, %{})
    |> put_change(:allow_public_edit, false)
  end

  @doc """
  Check if trip sharing is still valid.
  """
  def sharing_valid?(%__MODULE__{is_shareable: true, share_expires_at: expires_at}) 
    when not is_nil(expires_at) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end
  def sharing_valid?(%__MODULE__{is_shareable: true, share_expires_at: nil}), do: true
  def sharing_valid?(_), do: false

  @doc """
  Get share URL for a trip.
  """
  def share_url(%__MODULE__{share_token: token}) when not is_nil(token) do
    "#{get_base_url()}/shared/trips/#{token}"
  end
  def share_url(_), do: nil

  @doc """
  Check if user can edit this trip.
  """
  def can_edit?(trip, user_id) do
    cond do
      trip.user_id == user_id -> true
      trip.allow_public_edit and sharing_valid?(trip) -> true
      true -> false
    end
  end

  # Private helper functions for sharing

  defp build_share_permissions(attrs) do
    %{
      "allow_view" => true,  # Always allow viewing shared trips
      "allow_edit" => Map.get(attrs, "allow_public_edit", false),
      "allow_comment" => Map.get(attrs, "allow_comments", true),
      "allow_suggest" => Map.get(attrs, "allow_suggestions", true),
      "require_approval" => Map.get(attrs, "require_approval_for_edits", true)
    }
  end

  defp get_base_url do
    # In production, this should come from application config
    Application.get_env(:phoenix_backend, :frontend_url, "http://localhost:3000")
  end

  @doc """
  Creates a sample activity structure for reference.
  """
  def sample_activity_structures do
    %{
      poi_activity: %{
        "type" => "poi",
        "name" => "Golden Gate Bridge",
        "description" => "Iconic San Francisco landmark",
        "duration_minutes" => 120,
        "start_time" => "10:00",
        "poi_id" => "abc123",
        "category" => "attraction",
        "location" => %{
          "name" => "Golden Gate Bridge",
          "lat" => 37.8199,
          "lng" => -122.4783,
          "place_id" => "ChIJw____96GhYAR4jReCOSHO-E"
        },
        "booking" => %{
          "required" => false,
          "url" => nil,
          "notes" => ""
        },
        "cost" => %{
          "amount" => 0,
          "currency" => "USD",
          "per_person" => true
        }
      },
      user_activity: %{
        "type" => "user_defined",
        "name" => "Beach walk at sunset",
        "description" => "Relaxing walk along the beach",
        "duration_minutes" => 60,
        "start_time" => "18:30",
        "category" => "recreation",
        "location" => %{
          "name" => "Baker Beach",
          "lat" => 37.7938,
          "lng" => -122.4823,
          "place_id" => nil
        },
        "notes" => "Bring camera for sunset photos",
        "difficulty" => "easy"
      }
    }
  end
end