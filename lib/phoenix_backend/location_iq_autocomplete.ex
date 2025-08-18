defmodule RouteWiseApi.LocationIQAutocomplete do
  @moduledoc """
  LocationIQ Autocomplete API client for place search.
  Provides fast global autocomplete with structured responses.
  """

  require Logger
  alias HTTPoison

  @base_url "https://api.locationiq.com/v1"
  @default_timeout 5_000
  @default_limit 10

  @doc """
  Search places using LocationIQ autocomplete API.
  
  ## Parameters
  - query: Search term (minimum 2 characters)
  - opts: Options map with optional keys:
    - limit: Maximum results (default: 10, max: 50)
    - country_codes: List of 2-letter country codes to restrict search
    - accept_language: Language preference (default: "en")
    - viewbox: Geographic bounds to prioritize results
    - bounded: Restrict results to viewbox (default: false)
    - tag: Specific place types to search
    - addressdetails: Include structured address (default: true)
  
  ## Returns
  {:ok, [%{name: "...", lat: 12.34, lon: 56.78, ...}]} | {:error, reason}
  """
  def search(query, opts \\ %{}) do
    with :ok <- validate_query(query),
         {:ok, url} <- build_autocomplete_url(query, opts),
         {:ok, response} <- make_request(url),
         {:ok, results} <- parse_autocomplete_response(response) do
      {:ok, format_results(results)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Search specific types of places (restaurants, hotels, attractions, etc.).
  
  ## Parameters
  - query: Search term
  - place_type: One of :restaurant, :hotel, :attraction, :shop, :gas_station, etc.
  - opts: Same options as search/2
  """
  def search_by_type(query, place_type, opts \\ %{}) do
    tag = map_place_type_to_tag(place_type)
    updated_opts = Map.put(opts, :tag, tag)
    search(query, updated_opts)
  end

  @doc """
  Get place details by place_id (if available from search results).
  """
  def get_place_details(place_id, opts \\ %{}) do
    with {:ok, url} <- build_details_url(place_id, opts),
         {:ok, response} <- make_request(url),
         {:ok, result} <- parse_details_response(response) do
      {:ok, format_detailed_result(result)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp validate_query(query) when is_binary(query) do
    trimmed = String.trim(query)
    if String.length(trimmed) >= 2 do
      :ok
    else
      {:error, "Query must be at least 2 characters long"}
    end
  end
  defp validate_query(_), do: {:error, "Query must be a string"}

  defp build_autocomplete_url(query, opts) do
    api_key = get_api_key()
    if api_key do
      params = build_autocomplete_params(query, opts, api_key)
      url = "#{@base_url}/autocomplete?" <> URI.encode_query(params)
      {:ok, url}
    else
      {:error, "LocationIQ API key not configured"}
    end
  end

  defp build_details_url(place_id, opts) do
    api_key = get_api_key()
    if api_key do
      params = build_details_params(place_id, opts, api_key)
      url = "#{@base_url}/details?" <> URI.encode_query(params)
      {:ok, url}
    else
      {:error, "LocationIQ API key not configured"}
    end
  end

  defp build_autocomplete_params(query, opts, api_key) do
    base_params = %{
      "key" => api_key,
      "q" => query,
      "format" => "json",
      "addressdetails" => Map.get(opts, :addressdetails, 1),
      "limit" => min(Map.get(opts, :limit, @default_limit), 50),
      "accept-language" => Map.get(opts, :accept_language, "en")
    }

    base_params
    |> maybe_add_country_codes(opts)
    |> maybe_add_viewbox(opts)
    |> maybe_add_bounded(opts)
    |> maybe_add_tag(opts)
  end

  defp build_details_params(place_id, opts, api_key) do
    %{
      "key" => api_key,
      "place_id" => place_id,
      "format" => "json",
      "addressdetails" => Map.get(opts, :addressdetails, 1),
      "accept-language" => Map.get(opts, :accept_language, "en")
    }
  end

  defp maybe_add_country_codes(params, %{country_codes: codes}) when is_list(codes) do
    Map.put(params, "countrycodes", Enum.join(codes, ","))
  end
  defp maybe_add_country_codes(params, _), do: params

  defp maybe_add_viewbox(params, %{viewbox: viewbox}) when is_binary(viewbox) do
    Map.put(params, "viewbox", viewbox)
  end
  defp maybe_add_viewbox(params, _), do: params

  defp maybe_add_bounded(params, %{bounded: true}) do
    Map.put(params, "bounded", 1)
  end
  defp maybe_add_bounded(params, _), do: params

  defp maybe_add_tag(params, %{tag: tag}) when is_binary(tag) do
    Map.put(params, "tag", tag)
  end
  defp maybe_add_tag(params, _), do: params

  defp make_request(url) do
    headers = [
      {"User-Agent", "RouteWise/1.0"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.get(url, headers, timeout: @default_timeout, recv_timeout: @default_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        Logger.warning("LocationIQ API error #{status}: #{body}")
        {:error, "API request failed with status #{status}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warning("LocationIQ API connection error: #{inspect(reason)}")
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  defp parse_autocomplete_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, results} when is_list(results) ->
        {:ok, results}
      {:ok, %{"error" => error}} ->
        {:error, "LocationIQ API error: #{error}"}
      {:ok, _} ->
        {:error, "Unexpected response format"}
      {:error, _} ->
        {:error, "Failed to parse JSON response"}
    end
  end

  defp parse_details_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, result} when is_map(result) ->
        {:ok, result}
      {:ok, %{"error" => error}} ->
        {:error, "LocationIQ API error: #{error}"}
      {:error, _} ->
        {:error, "Failed to parse JSON response"}
    end
  end

  defp format_results(results) do
    Enum.map(results, &format_result/1)
  end

  defp format_result(result) do
    %{
      id: result["place_id"],
      name: extract_name(result),
      display_name: result["display_name"],
      lat: parse_coordinate(result["lat"]),
      lon: parse_coordinate(result["lon"]),
      type: classify_place_type(result),
      category: result["category"],
      address: extract_address(result),
      country_code: result["address"]["country_code"] || extract_country_code(result),
      source: "locationiq"
    }
  end

  defp format_detailed_result(result) do
    %{
      id: result["place_id"],
      name: extract_name(result),
      display_name: result["display_name"],
      lat: parse_coordinate(result["lat"]),
      lon: parse_coordinate(result["lon"]),
      type: classify_place_type(result),
      category: result["category"],
      address: extract_address(result),
      country_code: result["address"]["country_code"] || extract_country_code(result),
      importance: result["importance"],
      source: "locationiq"
    }
  end

  defp extract_name(result) do
    result["name"] || 
    result["display_name"] |> String.split(",") |> hd() |> String.trim()
  end

  defp extract_address(result) do
    address = result["address"] || %{}
    
    parts = [
      address["house_number"],
      address["road"],
      address["neighbourhood"] || address["suburb"],
      address["city"] || address["town"] || address["village"],
      address["state"],
      address["country"]
    ]
    |> Enum.filter(&(&1 != nil))
    |> Enum.join(", ")

    if parts == "", do: result["display_name"], else: parts
  end

  defp extract_country_code(result) do
    result["display_name"]
    |> String.split(",")
    |> List.last()
    |> String.trim()
    |> case do
      country when byte_size(country) == 2 -> country
      _ -> nil
    end
  end

  defp classify_place_type(result) do
    case {result["type"], result["category"]} do
      {"country", _} -> 1  # Country
      {"state", _} -> 2    # State/Region
      {"city", _} -> 3     # City
      {"town", _} -> 3     # City
      {"village", _} -> 3  # City
      {_, "amenity"} -> 5  # POI
      {_, "tourism"} -> 5  # POI
      {_, "leisure"} -> 5  # POI
      {_, "shop"} -> 5     # POI
      _ -> 5               # Default to POI
    end
  end

  defp parse_coordinate(coord) when is_binary(coord) do
    case Float.parse(coord) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  defp parse_coordinate(coord) when is_number(coord), do: coord
  defp parse_coordinate(_), do: 0.0

  defp map_place_type_to_tag(place_type) do
    case place_type do
      :restaurant -> "amenity:restaurant"
      :hotel -> "tourism:hotel"
      :attraction -> "tourism:attraction"
      :shop -> "shop"
      :gas_station -> "amenity:fuel"
      :hospital -> "amenity:hospital"
      :school -> "amenity:school"
      :bank -> "amenity:bank"
      :airport -> "aeroway:aerodrome"
      _ -> nil
    end
  end

  defp get_api_key do
    Application.get_env(:phoenix_backend, :location_iq_api_key) ||
    System.get_env("LOCATION_IQ_API_KEY")
  end
end