defmodule RouteWiseApi.GooglePlaces do
  @moduledoc """
  Google Places API client for searching places, getting details, and autocomplete.
  """

  alias RouteWiseApi.GoogleAPITracker
  require Logger
  require RouteWiseApi.Assert
  import RouteWiseApi.Assert

  @base_url "https://maps.googleapis.com/maps/api/place"
  @photo_base_url "https://maps.googleapis.com/maps/api/place/photo"

  @doc """
  Search for places using text search.

  ## Examples

      iex> text_search("restaurants in San Francisco")
      {:ok, %{"results" => [%{"place_id" => "...", "name" => "..."}], "status" => "OK"}}

      iex> text_search("invalid query", location: %{lat: 37.7749, lng: -122.4194})
      {:ok, %{"results" => [], "status" => "ZERO_RESULTS"}}

  """
  def text_search(query, opts \\ []) do
    pre!(is_binary(query) and byte_size(query) > 0, "query must be non-empty string")
    pre!(is_list(opts), "opts must be a list")
    
    result = GoogleAPITracker.track_and_proceed(:places, fn ->
      params = build_text_search_params(query, opts)
      assert!(is_map(params), "build_text_search_params must return a map")
      assert!(Map.has_key?(params, "query"), "params must include query")
      assert!(Map.has_key?(params, "key"), "params must include API key")

      "#{@base_url}/textsearch/json"
      |> make_request(params)
      |> handle_response()
    end)
    
    post!(is_tuple(result) and tuple_size(result) == 2, "result must be 2-tuple")
    post!(elem(result, 0) in [:ok, :error], "result must be ok/error tuple")
    result
  end

  @doc """
  Search for nearby places.

  ## Examples

      iex> nearby_search(%{lat: 37.7749, lng: -122.4194}, radius: 1000)
      {:ok, %{"results" => [...], "status" => "OK"}}

  """
  def nearby_search(location, opts \\ []) do
    pre!(is_map(location), "location must be a map")
    pre!(Map.has_key?(location, :lat) and Map.has_key?(location, :lng), "location must have lat/lng keys")
    pre!(is_number(location.lat) and is_number(location.lng), "lat/lng must be numeric")
    pre!(location.lat >= -90 and location.lat <= 90, "latitude must be within valid range")
    pre!(location.lng >= -180 and location.lng <= 180, "longitude must be within valid range")
    pre!(is_list(opts), "opts must be a list")
    
    result = GoogleAPITracker.track_and_proceed(:places, fn ->
      params = build_nearby_search_params(location, opts)
      assert!(is_map(params), "build_nearby_search_params must return a map")
      assert!(Map.has_key?(params, "location"), "params must include location")
      assert!(Map.has_key?(params, "radius"), "params must include radius")
      assert!(Map.has_key?(params, "key"), "params must include API key")

      "#{@base_url}/nearbysearch/json"
      |> make_request(params)
      |> handle_response()
    end)
    
    post!(is_tuple(result) and tuple_size(result) == 2, "result must be 2-tuple")
    post!(elem(result, 0) in [:ok, :error], "result must be ok/error tuple")
    result
  end

  @doc """
  Get detailed information about a place.

  ## Examples

      iex> place_details("ChIJN1t_tDeuEmsRUsoyG83frY4")
      {:ok, %{"result" => %{"place_id" => "...", "name" => "..."}, "status" => "OK"}}

  """
  def place_details(place_id, opts \\ []) do
    pre!(is_binary(place_id) and byte_size(place_id) > 0, "place_id must be non-empty string")
    pre!(is_list(opts), "opts must be a list")
    
    result = GoogleAPITracker.track_and_proceed(:details, fn ->
      params = build_place_details_params(place_id, opts)
      assert!(is_map(params), "build_place_details_params must return a map")
      assert!(Map.has_key?(params, "place_id"), "params must include place_id")
      assert!(Map.has_key?(params, "key"), "params must include API key")

      "#{@base_url}/details/json"
      |> make_request(params)
      |> handle_response()
    end)
    
    post!(is_tuple(result) and tuple_size(result) == 2, "result must be 2-tuple")
    post!(elem(result, 0) in [:ok, :error], "result must be ok/error tuple")
    result
  end

  @doc """
  Get autocomplete suggestions for places.

  ## Examples

      iex> autocomplete("San Franc")
      {:ok, %{"predictions" => [...], "status" => "OK"}}

  """
  def autocomplete(input, opts \\ []) do
    pre!(is_binary(input) and byte_size(input) > 0, "input must be non-empty string")
    pre!(is_list(opts), "opts must be a list")
    
    result = GoogleAPITracker.track_and_proceed(:autocomplete, fn ->
      params = build_autocomplete_params(input, opts)
      assert!(is_map(params), "build_autocomplete_params must return a map")
      assert!(Map.has_key?(params, "input"), "params must include input")
      assert!(Map.has_key?(params, "key"), "params must include API key")

      "#{@base_url}/autocomplete/json"
      |> make_request(params)
      |> handle_response()
    end)
    
    post!(is_tuple(result) and tuple_size(result) == 2, "result must be 2-tuple")
    post!(elem(result, 0) in [:ok, :error], "result must be ok/error tuple")
    result
  end

  @doc """
  Get a photo URL for a place photo.

  ## Examples

      iex> photo_url("photo_reference_string", maxwidth: 400)
      "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=..."

  """
  def photo_url(photo_reference, opts \\ []) do
    pre!(is_binary(photo_reference) and byte_size(photo_reference) > 0, "photo_reference must be non-empty string")
    pre!(is_list(opts), "opts must be a list")
    
    params = build_photo_params(photo_reference, opts)
    assert!(is_map(params), "build_photo_params must return a map")
    assert!(Map.has_key?(params, "photo_reference"), "params must include photo_reference")
    assert!(Map.has_key?(params, "key"), "params must include API key")
    
    query_string = URI.encode_query(params)
    assert!(is_binary(query_string), "URI.encode_query must return a string")
    
    url = "#{@photo_base_url}?#{query_string}"
    post!(String.starts_with?(url, "https://"), "photo URL must be HTTPS")
    url
  end

  # Private functions

  defp make_request(url, params) do
    pre!(is_binary(url) and String.starts_with?(url, "https://"), "url must be HTTPS string")
    pre!(is_map(params), "params must be a map")
    pre!(Map.has_key?(params, "key"), "params must include API key")
    
    query_string = URI.encode_query(params)
    full_url = "#{url}?#{query_string}"
    assert!(String.contains?(full_url, "key="), "full URL must contain API key")

    Logger.debug("Making Google Places API request to: #{url}")

    case Finch.build(:get, full_url) |> Finch.request(RouteWiseApi.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        assert!(is_binary(body) and byte_size(body) > 0, "response body must be non-empty string")
        decoded = Jason.decode!(body)
        assert!(is_map(decoded), "response must decode to a map")
        {:ok, decoded}

      {:ok, %Finch.Response{status: status, body: body}} ->
        Logger.error("Google Places API error: #{status} - #{body}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("Google Places API request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  rescue
    e in Jason.DecodeError ->
      Logger.error("Failed to decode Google Places API response: #{inspect(e)}")
      {:error, {:decode_error, e}}

    error ->
      Logger.error("Unexpected error in Google Places API request: #{inspect(error)}")
      {:error, {:unexpected_error, error}}
  end

  defp handle_response({:ok, %{"status" => "OK"} = response}) do
    {:ok, response}
  end

  defp handle_response({:ok, %{"status" => "ZERO_RESULTS"} = response}) do
    {:ok, response}
  end

  defp handle_response({:ok, %{"status" => status, "error_message" => error_message}}) do
    Logger.error("Google Places API error: #{status} - #{error_message}")
    {:error, {:api_error, status, error_message}}
  end

  defp handle_response({:ok, %{"status" => status}}) do
    Logger.error("Google Places API error: #{status}")
    {:error, {:api_error, status}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end

  defp build_text_search_params(query, opts) do
    base_params = %{
      "query" => query,
      "key" => api_key()
    }

    base_params
    |> maybe_add_location(opts[:location])
    |> maybe_add_radius(opts[:radius])
    |> maybe_add_type(opts[:type])
    |> maybe_add_language(opts[:language])
    |> maybe_add_region(opts[:region])
  end

  defp build_nearby_search_params(location, opts) do
    base_params = %{
      "location" => "#{location.lat},#{location.lng}",
      "radius" => opts[:radius] || 5000,
      "key" => api_key()
    }

    base_params
    |> maybe_add_keyword(opts[:keyword])
    |> maybe_add_type(opts[:type])
    |> maybe_add_language(opts[:language])
    |> maybe_add_min_price(opts[:min_price])
    |> maybe_add_max_price(opts[:max_price])
  end

  defp build_place_details_params(place_id, opts) do
    base_params = %{
      "place_id" => place_id,
      "key" => api_key()
    }

    base_params
    |> maybe_add_fields(opts[:fields])
    |> maybe_add_language(opts[:language])
    |> maybe_add_region(opts[:region])
  end

  defp build_autocomplete_params(input, opts) do
    base_params = %{
      "input" => input,
      "key" => api_key()
    }

    base_params
    |> maybe_add_location(opts[:location])
    |> maybe_add_radius(opts[:radius])
    |> maybe_add_types(opts[:types])
    |> maybe_add_language(opts[:language])
    |> maybe_add_components(opts[:components])
  end

  defp build_photo_params(photo_reference, opts) do
    base_params = %{
      "photo_reference" => photo_reference,
      "key" => api_key()
    }

    base_params
    |> maybe_add_maxwidth(opts[:maxwidth])
    |> maybe_add_maxheight(opts[:maxheight])
  end

  # Parameter helper functions

  defp maybe_add_location(params, nil), do: params
  defp maybe_add_location(params, %{lat: lat, lng: lng}) do
    assert!(is_number(lat) and is_number(lng), "lat/lng must be numeric")
    assert!(lat >= -90 and lat <= 90, "latitude must be within valid range")
    assert!(lng >= -180 and lng <= 180, "longitude must be within valid range")
    
    location_string = "#{lat},#{lng}"
    assert!(String.contains?(location_string, ","), "location string must contain comma")
    Map.put(params, "location", location_string)
  end

  defp maybe_add_radius(params, nil), do: params
  defp maybe_add_radius(params, radius) do
    assert!(is_integer(radius) and radius > 0, "radius must be positive integer")
    assert!(radius <= 50_000, "radius cannot exceed 50km (Google Places limit)")
    Map.put(params, "radius", radius)
  end

  defp maybe_add_type(params, nil), do: params
  defp maybe_add_type(params, type), do: Map.put(params, "type", type)

  defp maybe_add_types(params, nil), do: params
  defp maybe_add_types(params, types) when is_list(types) do
    Map.put(params, "types", Enum.join(types, "|"))
  end
  defp maybe_add_types(params, types), do: Map.put(params, "types", types)

  defp maybe_add_language(params, nil), do: params
  defp maybe_add_language(params, language), do: Map.put(params, "language", language)

  defp maybe_add_region(params, nil), do: params
  defp maybe_add_region(params, region), do: Map.put(params, "region", region)

  defp maybe_add_keyword(params, nil), do: params
  defp maybe_add_keyword(params, keyword), do: Map.put(params, "keyword", keyword)

  defp maybe_add_min_price(params, nil), do: params
  defp maybe_add_min_price(params, min_price), do: Map.put(params, "minprice", min_price)

  defp maybe_add_max_price(params, nil), do: params
  defp maybe_add_max_price(params, max_price), do: Map.put(params, "maxprice", max_price)

  defp maybe_add_fields(params, nil), do: params
  defp maybe_add_fields(params, fields) when is_list(fields) do
    Map.put(params, "fields", Enum.join(fields, ","))
  end
  defp maybe_add_fields(params, fields), do: Map.put(params, "fields", fields)

  defp maybe_add_components(params, nil), do: params
  defp maybe_add_components(params, components), do: Map.put(params, "components", components)

  defp maybe_add_maxwidth(params, nil), do: params
  defp maybe_add_maxwidth(params, maxwidth), do: Map.put(params, "maxwidth", maxwidth)

  defp maybe_add_maxheight(params, nil), do: params
  defp maybe_add_maxheight(params, maxheight), do: Map.put(params, "maxheight", maxheight)

  defp api_key do
    key = System.get_env("GOOGLE_PLACES_API_KEY") ||
      Application.get_env(:phoenix_backend, :google_places_api_key) ||
      raise "Google Places API key not configured. Set GOOGLE_PLACES_API_KEY environment variable."
    
    post!(is_binary(key) and byte_size(key) > 0, "API key must be non-empty string")
    post!(byte_size(key) > 10, "API key seems too short to be valid")
    key
  end
end