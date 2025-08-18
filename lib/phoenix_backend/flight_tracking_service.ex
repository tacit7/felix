defmodule RouteWiseApi.FlightTrackingService do
  @moduledoc """
  Service for interacting with flight tracking APIs.
  
  Primary API: OpenSky Network (free, perfect for development/testing)
  
  ## Endpoints
  - `/states/all` - Live aircraft states
  - `/flights/departure` - Departures from airport
  - `/flights/arrival` - Arrivals to airport
  - `/tracks` - Historical flight tracks
  
  ## Rate Limits
  OpenSky Network applies rate limits to authenticated and anonymous requests.
  Anonymous requests are more limited but sufficient for development.
  
  ## Usage
  ```elixir
  # Get all live aircraft states
  {:ok, states} = FlightTrackingService.get_live_states()
  
  # Get flights departing from LAX in the last hour
  {:ok, flights} = FlightTrackingService.get_departures("KLAX", 3600)
  
  # Get flight track for specific aircraft
  {:ok, track} = FlightTrackingService.get_aircraft_track("abc123", 1640995200)
  ```
  """
  
  use HTTPoison.Base
  require Logger
  
  @base_url "https://opensky-network.org/api"
  @default_timeout 30_000
  
  # API Configuration
  @api_config %{
    base_url: @base_url,
    timeout: @default_timeout,
    headers: [
      {"Accept", "application/json"},
      {"User-Agent", "RouteWiseApi/1.0 (Contact: your-email@example.com)"}
    ]
  }
  
  @type state_vector :: %{
    icao24: String.t(),
    callsign: String.t() | nil,
    origin_country: String.t(),
    time_position: integer() | nil,
    last_contact: integer(),
    longitude: float() | nil,
    latitude: float() | nil,
    baro_altitude: float() | nil,
    on_ground: boolean(),
    velocity: float() | nil,
    true_track: float() | nil,
    vertical_rate: float() | nil,
    sensors: list() | nil,
    geo_altitude: float() | nil,
    squawk: String.t() | nil,
    spi: boolean() | nil,
    position_source: integer()
  }
  
  @type flight_data :: %{
    icao24: String.t(),
    first_seen: integer(),
    estDepartureAirport: String.t() | nil,
    lastSeen: integer(),
    estArrivalAirport: String.t() | nil,
    callsign: String.t() | nil,
    estDepartureAirportHorizDistance: integer() | nil,
    estDepartureAirportVertDistance: integer() | nil,
    estArrivalAirportHorizDistance: integer() | nil,
    estArrivalAirportVertDistance: integer() | nil,
    departureAirportCandidatesCount: integer() | nil,
    arrivalAirportCandidatesCount: integer() | nil
  }
  
  # HTTPoison.Base callbacks
  
  @doc false
  def process_request_url(url) do
    @base_url <> url
  end
  
  @doc false
  def process_request_headers(headers) do
    @api_config.headers ++ headers
  end
  
  @doc false
  def process_response_body(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end
  
  @doc false
  def process_request_options(options) do
    Keyword.put_new(options, :timeout, @api_config.timeout)
  end
  
  # Public API Functions
  
  @doc """
  Get current state vectors for all aircraft tracked by OpenSky Network.
  
  ## Parameters
  - `opts` - Optional parameters:
    - `:icao24` - Filter by specific aircraft ICAO 24-bit addresses (list of strings)
    - `:bbox` - Bounding box {min_lat, max_lat, min_lon, max_lon}
    - `:extended` - Include additional sensor information (boolean, default: false)
  
  ## Returns
  - `{:ok, %{time: integer, states: [state_vector]}}` - Success with timestamp and states
  - `{:error, reason}` - API error or network failure
  
  ## Examples
  ```elixir
  # Get all states
  {:ok, response} = get_live_states()
  
  # Get specific aircraft
  {:ok, response} = get_live_states(icao24: ["abc123", "def456"])
  
  # Get aircraft in bounding box (LA area)
  {:ok, response} = get_live_states(bbox: {33.7, 34.3, -118.7, -117.9})
  ```
  """
  @spec get_live_states(keyword()) :: {:ok, map()} | {:error, term()}
  def get_live_states(opts \\ []) do
    query_params = build_states_params(opts)
    url = "/states/all" <> query_params
    
    case get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, parse_states_response(body)}
      
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:error, :bad_request}
        
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}
        
      {:ok, %HTTPoison.Response{status_code: 429}} ->
        {:error, :rate_limit_exceeded}
        
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenSky API request failed: #{inspect(reason)}")
        {:error, {:network_error, reason}}
    end
  end
  
  @doc """
  Get flights departing from a specific airport within a time interval.
  
  ## Parameters
  - `airport_icao` - ICAO code of the airport (e.g., "KLAX", "KJFK")
  - `begin_time` - Start of time interval (Unix timestamp)
  - `end_time` - End of time interval (Unix timestamp, optional, defaults to now)
  
  ## Returns
  - `{:ok, [flight_data]}` - List of departure flights
  - `{:error, reason}` - API error
  """
  @spec get_departures(String.t(), integer(), integer() | nil) :: {:ok, [flight_data()]} | {:error, term()}
  def get_departures(airport_icao, begin_time, end_time \\ nil) do
    end_time = end_time || :os.system_time(:second)
    
    query = URI.encode_query([
      airport: airport_icao,
      begin: begin_time,
      end: end_time
    ])
    
    url = "/flights/departure?" <> query
    
    case get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} when is_list(body) ->
        flights = Enum.map(body, &parse_flight_data/1)
        {:ok, flights}
        
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenSky departures request failed: #{inspect(reason)}")
        {:error, {:network_error, reason}}
    end
  end
  
  @doc """
  Get flights arriving at a specific airport within a time interval.
  
  ## Parameters  
  - `airport_icao` - ICAO code of the airport
  - `begin_time` - Start of time interval (Unix timestamp)
  - `end_time` - End of time interval (Unix timestamp, optional, defaults to now)
  
  ## Returns
  - `{:ok, [flight_data]}` - List of arrival flights
  - `{:error, reason}` - API error
  """
  @spec get_arrivals(String.t(), integer(), integer() | nil) :: {:ok, [flight_data()]} | {:error, term()}
  def get_arrivals(airport_icao, begin_time, end_time \\ nil) do
    end_time = end_time || :os.system_time(:second)
    
    query = URI.encode_query([
      airport: airport_icao,
      begin: begin_time,
      end: end_time
    ])
    
    url = "/flights/arrival?" <> query
    
    case get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} when is_list(body) ->
        flights = Enum.map(body, &parse_flight_data/1)
        {:ok, flights}
        
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenSky arrivals request failed: #{inspect(reason)}")
        {:error, {:network_error, reason}}
    end
  end
  
  @doc """
  Get the track (trajectory) of a specific aircraft at a given time.
  
  ## Parameters
  - `icao24` - ICAO 24-bit address of the aircraft (lowercase hex string)
  - `time` - Unix timestamp for which to retrieve the track
  
  ## Returns
  - `{:ok, %{icao24: String.t(), callsign: String.t(), startTime: integer, endTime: integer, path: [waypoint]}}` 
  - `{:error, reason}` - API error
  
  ## Example
  ```elixir
  {:ok, track} = get_aircraft_track("abc123", 1640995200)
  ```
  """
  @spec get_aircraft_track(String.t(), integer()) :: {:ok, map()} | {:error, term()}
  def get_aircraft_track(icao24, time) do
    query = URI.encode_query([time: time])
    url = "/tracks/all?icao24=#{String.downcase(icao24)}&#{query}"
    
    case get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, parse_track_response(body, icao24)}
        
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :track_not_found}
        
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenSky track request failed: #{inspect(reason)}")
        {:error, {:network_error, reason}}
    end
  end
  
  @doc """
  Search for flights by callsign pattern.
  This is a convenience function that filters live states by callsign.
  
  ## Parameters
  - `callsign_pattern` - Pattern to match callsigns (case-insensitive)
  
  ## Returns
  - `{:ok, [state_vector]}` - Matching aircraft states
  - `{:error, reason}` - API error
  """
  @spec search_by_callsign(String.t()) :: {:ok, [state_vector()]} | {:error, term()}
  def search_by_callsign(callsign_pattern) do
    case get_live_states() do
      {:ok, %{states: states}} ->
        pattern = String.upcase(callsign_pattern)
        matching_states = Enum.filter(states, fn state ->
          case state.callsign do
            nil -> false
            callsign -> String.contains?(String.upcase(String.trim(callsign)), pattern)
          end
        end)
        {:ok, matching_states}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get aircraft within a specific geographic area.
  
  ## Parameters
  - `center` - `{lat, lon}` center coordinates
  - `radius_km` - Radius in kilometers
  
  ## Returns
  - `{:ok, [state_vector]}` - Aircraft within the area
  - `{:error, reason}` - API error
  """
  @spec get_aircraft_in_area({float(), float()}, float()) :: {:ok, [state_vector()]} | {:error, term()}
  def get_aircraft_in_area({center_lat, center_lon}, radius_km) do
    # Calculate bounding box from center and radius
    lat_delta = radius_km / 111.0  # Rough km per degree latitude
    lon_delta = radius_km / (111.0 * :math.cos(center_lat * :math.pi() / 180))
    
    bbox = {
      center_lat - lat_delta,  # min_lat
      center_lat + lat_delta,  # max_lat  
      center_lon - lon_delta,  # min_lon
      center_lon + lon_delta   # max_lon
    }
    
    get_live_states(bbox: bbox)
  end
  
  # Private helper functions
  
  defp build_states_params(opts) do
    params = []
    
    params = case Keyword.get(opts, :icao24) do
      nil -> params
      icao24_list when is_list(icao24_list) ->
        icao24_str = icao24_list |> Enum.map(&String.downcase/1) |> Enum.join(",")
        [{"icao24", icao24_str} | params]
    end
    
    params = case Keyword.get(opts, :bbox) do
      nil -> params
      {min_lat, max_lat, min_lon, max_lon} ->
        [
          {"lamin", min_lat},
          {"lamax", max_lat}, 
          {"lomin", min_lon},
          {"lomax", max_lon}
          | params
        ]
    end
    
    params = if Keyword.get(opts, :extended, false) do
      [{"extended", "1"} | params]
    else
      params
    end
    
    case params do
      [] -> ""
      _ -> "?" <> URI.encode_query(params)
    end
  end
  
  defp parse_states_response(%{"time" => time, "states" => states}) when is_list(states) do
    parsed_states = Enum.map(states, &parse_state_vector/1)
    %{time: time, states: parsed_states}
  end
  
  defp parse_states_response(%{"time" => time, "states" => nil}) do
    %{time: time, states: []}
  end
  
  defp parse_states_response(body) do
    Logger.warning("Unexpected states response format: #{inspect(body)}")
    %{time: :os.system_time(:second), states: []}
  end
  
  defp parse_state_vector([
    icao24, callsign, origin_country, time_position, last_contact,
    longitude, latitude, baro_altitude, on_ground, velocity, true_track,
    vertical_rate, sensors, geo_altitude, squawk, spi, position_source
  ]) do
    %{
      icao24: icao24,
      callsign: callsign && String.trim(callsign),
      origin_country: origin_country,
      time_position: time_position,
      last_contact: last_contact,
      longitude: longitude,
      latitude: latitude,
      baro_altitude: baro_altitude,
      on_ground: on_ground,
      velocity: velocity,
      true_track: true_track,
      vertical_rate: vertical_rate,
      sensors: sensors,
      geo_altitude: geo_altitude,
      squawk: squawk,
      spi: spi,
      position_source: position_source
    }
  end
  
  defp parse_flight_data([
    icao24, first_seen, est_departure_airport, last_seen, est_arrival_airport,
    callsign, est_departure_horiz_dist, est_departure_vert_dist,
    est_arrival_horiz_dist, est_arrival_vert_dist, 
    departure_candidates_count, arrival_candidates_count
  ]) do
    %{
      icao24: icao24,
      first_seen: first_seen,
      estDepartureAirport: est_departure_airport,
      lastSeen: last_seen,
      estArrivalAirport: est_arrival_airport,
      callsign: callsign && String.trim(callsign),
      estDepartureAirportHorizDistance: est_departure_horiz_dist,
      estDepartureAirportVertDistance: est_departure_vert_dist,
      estArrivalAirportHorizDistance: est_arrival_horiz_dist,
      estArrivalAirportVertDistance: est_arrival_vert_dist,
      departureAirportCandidatesCount: departure_candidates_count,
      arrivalAirportCandidatesCount: arrival_candidates_count
    }
  end
  
  defp parse_track_response(%{"icao24" => icao24, "callsign" => callsign, 
                              "startTime" => start_time, "endTime" => end_time,
                              "path" => path}, _icao24) when is_list(path) do
    parsed_path = Enum.map(path, fn
      [time, lat, lon, baro_alt, true_track, on_ground] ->
        %{
          time: time,
          latitude: lat,
          longitude: lon,
          baro_altitude: baro_alt,
          true_track: true_track,
          on_ground: on_ground
        }
      _ -> nil
    end) |> Enum.filter(&(&1 != nil))
    
    %{
      icao24: icao24,
      callsign: callsign && String.trim(callsign),
      startTime: start_time,
      endTime: end_time,
      path: parsed_path
    }
  end
  
  defp parse_track_response(body, icao24) do
    Logger.warning("Unexpected track response format for #{icao24}: #{inspect(body)}")
    %{
      icao24: icao24,
      callsign: nil,
      startTime: nil,
      endTime: nil,
      path: []
    }
  end
end