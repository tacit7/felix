defmodule RouteWiseApi.Repo.Migrations.CreateFlightTrackingTables do
  use Ecto.Migration

  def change do
    # Airports table for airport information
    create table(:airports, primary_key: false) do
      add :id,                  :integer,            primary_key: true
      add :icao,                :string,             null: false, size: 4
      add :iata,                :string,             size: 3
      add :name,                :string,             null: false
      add :city,                :string,             null: false
      add :country,             :string,             null: false
      add :latitude,            :float,              null: false
      add :longitude,           :float,              null: false
      add :altitude,            :integer             # Altitude in feet
      add :timezone,            :string
      add :dst,                 :string
      add :tz_database,         :string
      add :type,                :string              # airport, heliport, seaplane_base, etc.
      add :source,              :string              # Data source identifier
      
      timestamps(type: :utc_datetime)
    end
    
    # Aircraft table for aircraft information
    create table(:aircraft, primary_key: false) do
      add :id,                  :integer,            primary_key: true
      add :icao24,              :string,             null: false, size: 6
      add :registration,        :string              # Aircraft registration/tail number
      add :manufacturericao,    :string              # Manufacturer ICAO code
      add :manufacturername,    :string              # Full manufacturer name
      add :model,               :string              # Aircraft model
      add :typecode,            :string              # Aircraft type code
      add :serialnumber,        :string              # Aircraft serial number
      add :owner,               :string              # Aircraft owner
      add :operator,            :string              # Aircraft operator
      add :operator_callsign,   :string              # Operator callsign
      add :operator_icao,       :string              # Operator ICAO code
      add :operator_iata,       :string              # Operator IATA code
      add :first_flight_date,   :date                # First flight date
      add :category_description, :string             # Category (e.g., Light, Heavy)
      add :engines,             :integer             # Number of engines
      add :engine_type,         :string              # Engine type (piston, turboprop, jet)
      add :last_seen,           :utc_datetime        # Last time this aircraft was seen
      
      timestamps(type: :utc_datetime)
    end
    
    # Flights table for flight tracking data
    create table(:flights, primary_key: false) do
      add :id,                  :integer,            primary_key: true
      add :icao24,              :string,             null: false, size: 6
      add :callsign,            :string              # Flight callsign
      add :origin_country,      :string,             null: false
      add :first_seen,          :utc_datetime        # First time seen
      add :last_seen,           :utc_datetime        # Last time seen
      add :departure_airport,   :string              # ICAO code of departure airport
      add :arrival_airport,     :string              # ICAO code of arrival airport
      add :departure_time,      :utc_datetime        # Estimated departure time
      add :arrival_time,        :utc_datetime        # Estimated arrival time
      add :flight_status,       :string              # scheduled, active, landed, cancelled
      add :aircraft_id,         :integer             # Reference to aircraft table
      
      # Current position data (updated in real-time)
      add :latitude,            :float               # Current latitude
      add :longitude,           :float               # Current longitude
      add :altitude,            :float               # Barometric altitude in meters
      add :geo_altitude,        :float               # Geometric altitude in meters
      add :velocity,            :float               # Ground speed in m/s
      add :true_track,          :float               # Track angle in decimal degrees
      add :vertical_rate,       :float               # Vertical rate in m/s
      add :on_ground,           :boolean,            default: false
      add :squawk,              :string              # Transponder code
      add :position_source,     :integer             # Source of position data
      add :last_position_update, :utc_datetime       # Last position update time
      
      timestamps(type: :utc_datetime)
    end
    
    # Flight tracks table for storing historical flight paths
    create table(:flight_tracks, primary_key: false) do
      add :id,                  :integer,            primary_key: true
      add :flight_id,           :integer,            null: false
      add :icao24,              :string,             null: false, size: 6
      add :time,                :utc_datetime,       null: false
      add :latitude,            :float,              null: false
      add :longitude,           :float,              null: false
      add :altitude,            :float               # Barometric altitude in meters
      add :true_track,          :float               # Track angle in decimal degrees
      add :on_ground,           :boolean,            default: false
      add :source,              :string              # Data source
      
      timestamps(type: :utc_datetime)
    end
    
    # Live aircraft states table for caching current aircraft positions
    create table(:live_aircraft_states, primary_key: false) do
      add :id,                  :integer,            primary_key: true
      add :icao24,              :string,             null: false, size: 6
      add :callsign,            :string
      add :origin_country,      :string,             null: false
      add :time_position,       :utc_datetime        # Time of position report
      add :last_contact,        :utc_datetime,       null: false
      add :latitude,            :float
      add :longitude,           :float
      add :baro_altitude,       :float               # Barometric altitude in meters
      add :on_ground,           :boolean,            default: false
      add :velocity,            :float               # Ground speed in m/s
      add :true_track,          :float               # Track angle in decimal degrees
      add :vertical_rate,       :float               # Vertical rate in m/s
      add :geo_altitude,        :float               # Geometric altitude in meters
      add :squawk,              :string              # Transponder code
      add :spi,                 :boolean             # Special purpose indicator
      add :position_source,     :integer             # Source of position data
      add :data_source,         :string,             default: "opensky"
      add :last_updated,        :utc_datetime,       null: false
      
      timestamps(type: :utc_datetime)
    end
    
    # Create indexes for performance
    
    # Airports indexes
    create unique_index(:airports, [:icao])
    create index(:airports, [:iata])
    create index(:airports, [:country])
    create index(:airports, [:city])
    create index(:airports, [:latitude, :longitude])
    
    # Aircraft indexes
    create unique_index(:aircraft, [:icao24])
    create index(:aircraft, [:registration])
    create index(:aircraft, [:operator])
    create index(:aircraft, [:model])
    create index(:aircraft, [:last_seen])
    
    # Flights indexes
    create index(:flights, [:icao24])
    create index(:flights, [:callsign])
    create index(:flights, [:departure_airport])
    create index(:flights, [:arrival_airport])
    create index(:flights, [:flight_status])
    create index(:flights, [:first_seen])
    create index(:flights, [:last_seen])
    create index(:flights, [:latitude, :longitude])
    create index(:flights, [:last_position_update])
    
    # Flight tracks indexes
    create index(:flight_tracks, [:flight_id])
    create index(:flight_tracks, [:icao24])
    create index(:flight_tracks, [:time])
    create index(:flight_tracks, [:latitude, :longitude])
    
    # Live aircraft states indexes
    create unique_index(:live_aircraft_states, [:icao24])
    create index(:live_aircraft_states, [:callsign])
    create index(:live_aircraft_states, [:origin_country])
    create index(:live_aircraft_states, [:latitude, :longitude])
    create index(:live_aircraft_states, [:last_contact])
    create index(:live_aircraft_states, [:last_updated])
    create index(:live_aircraft_states, [:on_ground])
    
    # Foreign key constraints
    alter table(:flights) do
      modify :aircraft_id, references(:aircraft, on_delete: :nilify_all)
    end
    
    alter table(:flight_tracks) do
      modify :flight_id, references(:flights, on_delete: :delete_all)
    end
  end
end
