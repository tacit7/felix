defmodule RouteWiseApi.TypeUtils do
  @moduledoc """
  Utility functions for type conversions across the application.
  Consolidates ensure_* functions to eliminate code duplication.
  """

  @doc """
  Convert various numeric types to float with nil handling.
  
  ## Examples
      iex> TypeUtils.ensure_float(42)
      42.0
      
      iex> TypeUtils.ensure_float("3.14")
      3.14
      
      iex> TypeUtils.ensure_float(nil)
      nil
  """
  def ensure_float(value) when is_float(value), do: value
  def ensure_float(value) when is_integer(value), do: value / 1
  def ensure_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  def ensure_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> nil
    end
  end
  def ensure_float(nil), do: nil
  def ensure_float(_), do: nil

  @doc """
  Convert various numeric types to float with zero fallback for non-null invalid values.
  Used when you need a numeric default instead of nil.
  
  ## Examples
      iex> TypeUtils.ensure_float_or_zero("invalid")
      0.0
      
      iex> TypeUtils.ensure_float_or_zero(nil)
      0.0
  """
  def ensure_float_or_zero(value) when is_float(value), do: value
  def ensure_float_or_zero(value) when is_integer(value), do: value / 1
  def ensure_float_or_zero(value) when is_number(value), do: value / 1
  def ensure_float_or_zero(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  def ensure_float_or_zero(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  def ensure_float_or_zero(_), do: 0.0

  @doc """
  Convert various numeric types to Decimal.
  
  ## Examples
      iex> TypeUtils.ensure_decimal(42)
      #Decimal<42>
      
      iex> TypeUtils.ensure_decimal("3.14") 
      #Decimal<3.14>
      
      iex> TypeUtils.ensure_decimal(nil)
      nil
  """
  def ensure_decimal(nil), do: nil
  def ensure_decimal(%Decimal{} = decimal), do: decimal
  def ensure_decimal(value) when is_integer(value), do: Decimal.new(value)
  def ensure_decimal(value) when is_float(value), do: Decimal.from_float(value)
  def ensure_decimal(value) when is_binary(value) do
    try do
      case Float.parse(value) do
        {float_val, _} -> Decimal.from_float(float_val)
        :error -> nil
      end
    rescue
      _ -> nil
    end
  end
  def ensure_decimal(_), do: nil

  @doc """
  Parse coordinate values with proper validation for lat/lng domains.
  
  Handles real-world bad data gracefully with proper error reporting.
  
  ## Examples
      iex> TypeUtils.parse_coordinate("40.7128", :lat)
      {:ok, 40.7128}
      
      iex> TypeUtils.parse_coordinate("200", :lat)
      {:error, :out_of_bounds}
      
      iex> TypeUtils.parse_coordinate(nil, :lng)
      {:error, :missing}
  """
  @spec parse_coordinate(any(), :lat | :lng) :: {:ok, float()} | {:error, atom()}
  def parse_coordinate(nil, _kind), do: {:error, :missing}

  def parse_coordinate(value, kind) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {f, ""} -> 
        if valid_coordinate?(f, kind), do: {:ok, f}, else: {:error, :out_of_bounds}
      _ -> 
        {:error, :invalid_float}
    end
  end

  def parse_coordinate(%Decimal{} = decimal, kind) do
    try do
      f = Decimal.to_float(decimal)
      if valid_coordinate?(f, kind), do: {:ok, f}, else: {:error, :out_of_bounds}
    rescue
      _ -> {:error, :decimal_conversion_failed}
    end
  end

  def parse_coordinate(value, kind) when is_number(value) do
    f = value * 1.0
    if valid_coordinate?(f, kind), do: {:ok, f}, else: {:error, :out_of_bounds}
  end

  def parse_coordinate(value, _kind), do: {:error, {:unsupported_type, inspect(value)}}

  @doc """
  Validate coordinate values with proper domain separation for lat/lng.
  
  Includes NaN and Infinity guards for robust validation.
  """
  def valid_coordinate?(f, :lat) when is_float(f), do: finite?(f) and f >= -90.0 and f <= 90.0
  def valid_coordinate?(f, :lng) when is_float(f), do: finite?(f) and f >= -180.0 and f <= 180.0
  def valid_coordinate?(_, _), do: false

  @doc """
  Check if a float value is finite (not NaN or Infinity).
  """
  def finite?(f) when is_float(f), do: f == f and f not in [:infinity, :neg_infinity]

  @doc """
  Extract latitude and longitude coordinates from a map.
  
  Supports multiple field naming conventions and provides detailed error reporting.
  
  ## Examples
      iex> TypeUtils.extract_coordinates(%{lat: 40.7, lng: -74.0})
      {:ok, {40.7, -74.0}}
      
      iex> TypeUtils.extract_coordinates(%{latitude: "40.7", longitude: "-74.0"})
      {:ok, {40.7, -74.0}}
  """
  @spec extract_coordinates(map()) :: {:ok, {float(), float()}} | {:error, String.t()}
  def extract_coordinates(data) when is_map(data) do
    with {:ok, lat} <- get_latitude(data),
         {:ok, lng} <- get_longitude(data) do
      {:ok, {lat, lng}}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  def extract_coordinates(_), do: {:error, "input must be a map"}

  # Private helper functions for coordinate extraction
  
  defp get_latitude(data) do
    lat_value = Map.get(data, :lat) || Map.get(data, :latitude)
    case parse_coordinate(lat_value, :lat) do
      {:ok, lat} -> {:ok, lat}
      {:error, :missing} -> {:error, "missing latitude field (:lat or :latitude)"}
      {:error, reason} -> {:error, "invalid latitude: #{reason}"}
    end
  end

  defp get_longitude(data) do
    lng_value = Map.get(data, :lng) || Map.get(data, :longitude)
    case parse_coordinate(lng_value, :lng) do
      {:ok, lng} -> {:ok, lng}
      {:error, :missing} -> {:error, "missing longitude field (:lng or :longitude)"}
      {:error, reason} -> {:error, "invalid longitude: #{reason}"}
    end
  end
end