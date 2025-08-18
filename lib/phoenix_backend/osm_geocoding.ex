defmodule RouteWiseApi.OSMGeocoding do
  @moduledoc """
  OpenStreetMap Nominatim geocoding service for fetching geographic bounds.
  
  Uses the free Nominatim API to get bounding boxes for cities, territories, 
  states, and other geographic entities. Rate limited to 1 request/second.
  """
  
  require Logger
  
  @nominatim_base_url "https://nominatim.openstreetmap.org"
  @rate_limit_ms 1100  # Be respectful to free service (1 req/sec + buffer)
  
  @doc """
  Fetch geographic bounds for a location using OSM Nominatim API.
  
  Returns bounding box coordinates and calculated search radius.
  
  ## Examples
  
      iex> OSMGeocoding.fetch_bounds("Puerto Rico")
      {:ok, %{
        bbox_north: 18.520000,
        bbox_south: 17.880000,
        bbox_east: -65.220000,
        bbox_west: -67.950000,
        search_radius_meters: 180000,
        source: "osm",
        display_name: "Puerto Rico, United States"
      }}
  """
  def fetch_bounds(location_name, opts \\ []) do
    Logger.info("🌍 Fetching bounds for '#{location_name}' from OSM Nominatim")
    
    # Rate limiting - be nice to free service
    :timer.sleep(@rate_limit_ms)
    
    params = %{
      "q" => location_name,
      "format" => "json",
      "limit" => "1",
      "addressdetails" => "1",
      "extratags" => "1"
    }
    
    url = @nominatim_base_url <> "/search?" <> URI.encode_query(params)
    
    headers = [
      {"User-Agent", "RouteWise-Phoenix/1.0 (route-wise.app; contact@route-wise.app)"}
    ]
    
    case HTTPoison.get(url, headers, timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, [result | _]} ->
            parse_nominatim_result(result, location_name)
          {:ok, []} ->
            Logger.warning("⚠️ No results found for '#{location_name}' in OSM Nominatim")
            {:error, :not_found}
          {:error, reason} ->
            Logger.error("❌ Failed to parse Nominatim response: #{inspect(reason)}")
            {:error, :parse_error}
        end
      
      {:ok, %{status_code: status}} ->
        Logger.error("❌ Nominatim API returned status #{status}")
        {:error, {:http_error, status}}
      
      {:error, reason} ->
        Logger.error("❌ Failed to fetch from Nominatim: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Parse Nominatim result and extract bounding box information.
  """
  defp parse_nominatim_result(result, location_name) do
    case result do
      %{"boundingbox" => [south, north, west, east]} = data ->
        # Parse coordinates
        bbox_south = parse_decimal(south)
        bbox_north = parse_decimal(north)
        bbox_west = parse_decimal(west)
        bbox_east = parse_decimal(east)
        
        # Calculate search radius (half the maximum dimension)
        lat_distance = (bbox_north - bbox_south) * 111_000  # ~111km per degree lat
        lng_distance = (bbox_east - bbox_west) * 111_000 * 
                      :math.cos((bbox_north + bbox_south) / 2 * :math.pi / 180)
        
        search_radius = round(max(lat_distance, lng_distance) / 2)
        
        result_data = %{
          bbox_north: bbox_north,
          bbox_south: bbox_south,
          bbox_east: bbox_east,
          bbox_west: bbox_west,
          search_radius_meters: search_radius,
          source: "osm",
          display_name: Map.get(data, "display_name"),
          osm_type: Map.get(data, "osm_type"),
          osm_class: Map.get(data, "class"),
          place_rank: Map.get(data, "place_rank")
        }
        
        Logger.info("✅ Found bounds for '#{location_name}': #{search_radius/1000}km radius")
        {:ok, result_data}
      
      _ ->
        Logger.warning("⚠️ No bounding box in Nominatim result for '#{location_name}'")
        {:error, :no_bounds}
    end
  end
  
  @doc """
  Parse a string coordinate to Decimal.
  """
  defp parse_decimal(coord_string) when is_binary(coord_string) do
    case Decimal.parse(coord_string) do
      {decimal, ""} -> Decimal.to_float(decimal)
      _ -> String.to_float(coord_string)
    end
  end
  
  defp parse_decimal(coord) when is_number(coord), do: coord
  
  @doc """
  Batch fetch bounds for multiple locations with rate limiting.
  """
  def batch_fetch_bounds(locations) when is_list(locations) do
    Logger.info("🌍 Batch fetching bounds for #{length(locations)} locations")
    
    results = Enum.map(locations, fn location ->
      case fetch_bounds(location) do
        {:ok, bounds} -> {location, {:ok, bounds}}
        {:error, reason} -> {location, {:error, reason}}
      end
    end)
    
    success_count = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
    Logger.info("✅ Successfully fetched bounds for #{success_count}/#{length(locations)} locations")
    
    results
  end
  
  @doc """
  Update city record with geographic bounds from OSM.
  """
  def update_city_bounds(city) do
    location_query = build_location_query(city)
    
    case fetch_bounds(location_query) do
      {:ok, bounds} ->
        update_attrs = %{
          bbox_north: bounds.bbox_north,
          bbox_south: bounds.bbox_south,
          bbox_east: bounds.bbox_east,
          bbox_west: bounds.bbox_west,
          search_radius_meters: bounds.search_radius_meters,
          bounds_source: "osm",
          bounds_updated_at: DateTime.utc_now()
        }
        
        city
        |> RouteWiseApi.Places.City.changeset(update_attrs)
        |> RouteWiseApi.Repo.update()
        
      {:error, reason} ->
        Logger.warning("⚠️ Failed to update bounds for #{city.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Build a location query string for OSM Nominatim search.
  """
  defp build_location_query(city) do
    # Build query: "City, State, Country" or "Territory" for best results
    cond do
      city.country_code == "pr" ->
        # Puerto Rico is a territory
        "Puerto Rico"
      
      city.state && city.country ->
        "#{city.name}, #{city.state}, #{city.country}"
      
      city.country ->
        "#{city.name}, #{city.country}"
      
      true ->
        city.name
    end
  end
end