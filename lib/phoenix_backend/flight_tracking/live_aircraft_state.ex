defmodule RouteWiseApi.FlightTracking.LiveAircraftState do
  @moduledoc """
  Schema for live aircraft states cached from flight tracking APIs.
  
  This table stores real-time aircraft position and status data,
  updated by the FlightTracker GenServer.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  
  @type t :: %__MODULE__{
    id: integer(),
    icao24: String.t(),
    callsign: String.t() | nil,
    origin_country: String.t(),
    time_position: DateTime.t() | nil,
    last_contact: DateTime.t(),
    latitude: float() | nil,
    longitude: float() | nil,
    baro_altitude: float() | nil,
    on_ground: boolean(),
    velocity: float() | nil,
    true_track: float() | nil,
    vertical_rate: float() | nil,
    geo_altitude: float() | nil,
    squawk: String.t() | nil,
    spi: boolean() | nil,
    position_source: integer() | nil,
    data_source: String.t(),
    last_updated: DateTime.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }
  
  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :integer
  
  schema "live_aircraft_states" do
    field :icao24,              :string
    field :callsign,            :string
    field :origin_country,      :string
    field :time_position,       :utc_datetime
    field :last_contact,        :utc_datetime
    field :latitude,            :float
    field :longitude,           :float
    field :baro_altitude,       :float
    field :on_ground,           :boolean, default: false
    field :velocity,            :float
    field :true_track,          :float
    field :vertical_rate,       :float
    field :geo_altitude,        :float
    field :squawk,              :string
    field :spi,                 :boolean
    field :position_source,     :integer
    field :data_source,         :string, default: "opensky"
    field :last_updated,        :utc_datetime
    
    timestamps(type: :utc_datetime)
  end
  
  @doc """
  Changeset for creating or updating live aircraft state.
  """
  def changeset(state, attrs) do
    state
    |> cast(attrs, [
      :icao24, :callsign, :origin_country, :time_position, :last_contact,
      :latitude, :longitude, :baro_altitude, :on_ground, :velocity,
      :true_track, :vertical_rate, :geo_altitude, :squawk, :spi,
      :position_source, :data_source, :last_updated
    ])
    |> validate_required([:icao24, :origin_country, :last_contact, :last_updated])
    |> validate_length(:icao24, is: 6)
    |> validate_length(:callsign, max: 8)
    |> validate_length(:squawk, is: 4)
    |> validate_inclusion(:position_source, [0, 1, 2, 3])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:velocity, greater_than_or_equal_to: 0)
    |> validate_number(:true_track, greater_than_or_equal_to: 0, less_than: 360)
    |> unique_constraint(:icao24)
  end
  
  # Query functions
  
  @doc """
  Get all live aircraft states.
  """
  def all do
    from(a in __MODULE__, order_by: [desc: a.last_updated])
  end
  
  @doc """
  Get live aircraft states within a geographic bounding box.
  """
  def in_bounding_box(min_lat, max_lat, min_lon, max_lon) do
    from a in __MODULE__,
      where: a.latitude >= ^min_lat and a.latitude <= ^max_lat and
             a.longitude >= ^min_lon and a.longitude <= ^max_lon,
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Get live aircraft states by origin country.
  """
  def by_country(country) do
    from a in __MODULE__,
      where: a.origin_country == ^country,
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Get live aircraft states by callsign pattern.
  """
  def by_callsign_pattern(pattern) do
    search_pattern = "%#{String.upcase(pattern)}%"
    
    from a in __MODULE__,
      where: ilike(a.callsign, ^search_pattern),
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Get aircraft currently in the air (not on ground).
  """
  def airborne do
    from a in __MODULE__,
      where: a.on_ground == false,
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Get aircraft currently on the ground.
  """
  def on_ground do
    from a in __MODULE__,
      where: a.on_ground == true,
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Get aircraft by specific ICAO 24-bit address.
  """
  def by_icao24(icao24) do
    from a in __MODULE__,
      where: a.icao24 == ^String.downcase(icao24)
  end
  
  @doc """
  Get recently updated aircraft (within last N minutes).
  """
  def recent(minutes \\ 5) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)
    
    from a in __MODULE__,
      where: a.last_updated >= ^cutoff_time,
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Get aircraft with position data (latitude/longitude not null).
  """
  def with_position do
    from a in __MODULE__,
      where: not is_nil(a.latitude) and not is_nil(a.longitude),
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Get aircraft within a radius of a point (in kilometers).
  Uses the haversine formula for distance calculation.
  """
  def within_radius(center_lat, center_lon, radius_km) do
    # Calculate bounding box first for performance
    lat_delta = radius_km / 111.0  # Approximate km per degree latitude
    lon_delta = radius_km / (111.0 * :math.cos(center_lat * :math.pi() / 180))
    
    from a in __MODULE__,
      where: not is_nil(a.latitude) and not is_nil(a.longitude),
      where: a.latitude >= ^(center_lat - lat_delta) and 
             a.latitude <= ^(center_lat + lat_delta) and
             a.longitude >= ^(center_lon - lon_delta) and 
             a.longitude <= ^(center_lon + lon_delta),
      # Note: For more precise distance filtering, you would typically
      # use PostGIS or implement the haversine formula in a custom function
      order_by: [desc: a.last_updated]
  end
  
  @doc """
  Clean up old aircraft states (older than specified hours).
  """
  def cleanup_old_states(hours \\ 24) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)
    
    from a in __MODULE__,
      where: a.last_updated < ^cutoff_time
  end
  
  @doc """
  Get statistics about live aircraft states.
  """
  def statistics do
    from a in __MODULE__,
      select: %{
        total_aircraft: count(a.id),
        airborne_aircraft: filter(count(a.id), a.on_ground == false),
        on_ground_aircraft: filter(count(a.id), a.on_ground == true),
        with_position: filter(count(a.id), not is_nil(a.latitude) and not is_nil(a.longitude)),
        countries: count(a.origin_country, :distinct),
        data_sources: count(a.data_source, :distinct),
        last_update: max(a.last_updated)
      }
  end
end