# Google Geocoding Service
# Provides geocoding functionality using Google Maps Geocoding API

defmodule RouteWiseApi.GoogleGeocoding do
  @moduledoc """
  Service for geocoding addresses and place names using Google Maps Geocoding API.
  
  Used as a fallback when LocationIQ and database searches fail to find locations.
  Automatically stores successful results in the database for future use.
  """
  
  require Logger
  alias RouteWiseApi.{Places, Repo}
  alias RouteWiseApi.Places.Location

  @base_url "https://maps.googleapis.com/maps/api/geocode/json"

  @doc """
  Geocode a location query using Google Maps API.
  
  ## Parameters
  - query: Location string to geocode
  - opts: Options (country_code, etc.)
  
  ## Returns
  - {:ok, location_data} - Successful geocoding with coordinates
  - {:error, reason} - Failed to geocode
  
  ## Examples
      iex> geocode("Cagua, Puerto Rico")
      {:ok, %{name: "Cagua", lat: 18.237, lng: -66.037, ...}}
  """
  def geocode(query, opts \\ []) do
    api_key = get_api_key()
    
    params = build_geocode_params(query, opts, api_key)
    
    Logger.info("🌍 Google Geocoding: #{query}")
    
    case HTTPoison.get(@base_url, [], params: params, timeout: 10000) do
      {:ok, %{status_code: 200, body: body}} ->
        handle_geocode_response(body, query)
        
      {:ok, %{status_code: status}} ->
        Logger.error("Google Geocoding HTTP error: #{status}")
        {:error, {:http_error, status}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Google Geocoding request failed: #{reason}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Geocode a location and store the result in the database.
  
  This is the enhanced version used by the location disambiguation system.
  Stores successful results as City records for future searches.
  """
  def geocode_and_store(query, opts \\ []) do
    case geocode(query, opts) do
      {:ok, location_data} ->
        # Store in database for future searches
        case store_as_city(location_data, query) do
          {:ok, city} ->
            Logger.info("📍 Stored new city from Google: #{city.display_name}")
            {:ok, format_city_result(city)}
          {:error, reason} ->
            Logger.warn("Failed to store city in database: #{inspect(reason)}")
            # Return the geocoded data even if storage fails
            {:ok, location_data}
        end
        
      error -> error
    end
  end

  # Private helper functions

  defp get_api_key do
    System.get_env("GOOGLE_MAPS_API_KEY") || 
    Application.get_env(:phoenix_backend, :google_maps)[:api_key] ||
    raise "Google Maps API key not configured. Set GOOGLE_MAPS_API_KEY environment variable."
  end

  defp build_geocode_params(query, opts, api_key) do
    base_params = %{
      address: query,
      key: api_key
    }
    
    # Add country restriction if provided
    params = case Keyword.get(opts, :country_code) do
      nil -> base_params
      country_code -> Map.put(base_params, :components, "country:#{country_code}")
    end
    
    # Add region bias if provided
    case Keyword.get(opts, :region) do
      nil -> params
      region -> Map.put(params, :region, region)
    end
  end

  defp handle_geocode_response(body, original_query) do
    case Jason.decode(body) do
      {:ok, %{"status" => "OK", "results" => [result | _]}} ->
        parse_geocode_result(result, original_query)
        
      {:ok, %{"status" => "ZERO_RESULTS"}} ->
        Logger.info("Google Geocoding: No results for '#{original_query}'")
        {:error, :no_results}
        
      {:ok, %{"status" => status}} ->
        Logger.error("Google Geocoding API error: #{status}")
        {:error, {:api_error, status}}
        
      {:error, json_error} ->
        Logger.error("Google Geocoding JSON decode error: #{inspect(json_error)}")
        {:error, :json_decode}
    end
  end

  defp parse_geocode_result(result, original_query) do
    location = get_in(result, ["geometry", "location"])
    formatted_address = result["formatted_address"]
    address_components = result["address_components"] || []
    
    lat = location["lat"]
    lng = location["lng"]
    
    if lat && lng do
      # Extract city name and location details
      city_info = extract_location_info(address_components, formatted_address, original_query)
      
      location_data = %{
        name: city_info.name,
        display_name: formatted_address,
        lat: lat,
        lon: lng,  # Use 'lon' for consistency with LocationIQ format
        lng: lng,  # Also provide 'lng' for convenience
        formatted_address: formatted_address,
        type: "locality",
        state: city_info.state,
        country: city_info.country,
        country_code: city_info.country_code,
        source: :google
      }
      
      Logger.info("✅ Google Geocoding success: #{lat}, #{lng} - #{formatted_address}")
      {:ok, location_data}
    else
      Logger.error("Google Geocoding: Empty coordinates")
      {:error, :empty_coordinates}
    end
  end

  defp extract_location_info(address_components, formatted_address, original_query) do
    # Extract components
    locality = find_component(address_components, "locality") || 
               find_component(address_components, "administrative_area_level_2")
    state = find_component(address_components, "administrative_area_level_1")
    country = find_component(address_components, "country")
    country_code = find_component_short(address_components, "country")
    
    # Use locality from components, or extract from original query if not found
    city_name = locality || extract_city_from_query(original_query)
    
    %{
      name: city_name,
      state: state,
      country: country,
      country_code: String.downcase(country_code || "")
    }
  end

  defp find_component(components, type) do
    case Enum.find(components, fn comp -> type in comp["types"] end) do
      nil -> nil
      component -> component["long_name"]
    end
  end

  defp find_component_short(components, type) do
    case Enum.find(components, fn comp -> type in comp["types"] end) do
      nil -> nil
      component -> component["short_name"]
    end
  end

  defp extract_city_from_query(query) do
    # Extract first part before comma as city name
    query
    |> String.split(",")
    |> List.first()
    |> String.trim()
  end

  defp store_as_city(location_data, original_query) do
    # Create unique place ID for Google results
    place_id = "google_#{:crypto.hash(:md5, original_query) |> Base.encode16(case: :lower)}"
    
    # Check if already exists
    case Repo.get_by(City, location_iq_place_id: place_id) do
      nil ->
        # Create new city record
        city_attrs = %{
          location_iq_place_id: place_id,
          name: location_data.name,
          display_name: location_data.display_name,
          latitude: Decimal.new(to_string(location_data.lat)),
          longitude: Decimal.new(to_string(location_data.lon)),
          city_type: location_data.type,
          state: location_data.state,
          country: location_data.country,
          country_code: location_data.country_code,
          search_count: 1,
          last_searched_at: DateTime.utc_now()
        }
        
        %Location{}
        |> Location.changeset(city_attrs)
        |> Repo.insert()
        
      existing_city ->
        # Update search count
        existing_city
        |> Location.changeset(%{
          search_count: existing_city.search_count + 1,
          last_searched_at: DateTime.utc_now()
        })
        |> Repo.update()
    end
  end

  defp format_city_result(city) do
    %{
      id: city.id,
      place_id: city.location_iq_place_id,
      name: city.name,
      display_name: city.display_name,
      lat: Decimal.to_float(city.latitude),
      lon: Decimal.to_float(city.longitude),
      lng: Decimal.to_float(city.longitude),  # Provide both for compatibility
      type: city.city_type,
      state: city.state,
      country: city.country,
      country_code: city.country_code,
      source: :google
    }
  end
end