# Location Disambiguation Service
# Handles ambiguous location queries and provides smart suggestions

defmodule RouteWiseApi.LocationDisambiguation do
  @moduledoc """
  Service for handling ambiguous location searches and providing disambiguation.
  
  ## Examples
  
      # Ambiguous search
      iex> LocationDisambiguation.disambiguate("Ponce")
      {:ambiguous, [
        %{name: "Ponce", country: "Puerto Rico", display_name: "Ponce, Puerto Rico"},
        %{name: "Ponce", country: "United States", display_name: "Ponce, Texas, United States"}
      ]}
      
      # Specific search  
      iex> LocationDisambiguation.disambiguate("Ponce, Puerto Rico")
      {:ok, %{name: "Ponce", country: "Puerto Rico"}}
  """
  
  alias RouteWiseApi.{Places, Repo, GoogleGeocoding}
  alias RouteWiseApi.Places.City
  import Ecto.Query
  require Logger

  @doc """
  Disambiguate a location query and return either:
  - {:ok, location} - Single unambiguous match
  - {:ambiguous, [locations]} - Multiple possible matches 
  - {:error, reason} - No matches found
  """
  def disambiguate(location_query) when is_binary(location_query) do
    normalized_query = normalize_query(location_query)
    
    cond do
      # Already specific (contains country/state)
      is_specific_query?(location_query) ->
        find_specific_location(location_query)
        
      # Ambiguous query - search for all matches
      true ->
        find_all_matches(normalized_query)
    end
  end

  @doc """
  Get suggested disambiguation options for a location.
  Returns formatted suggestions for frontend display.
  """
  def get_suggestions(location_query) do
    case disambiguate(location_query) do
      {:ambiguous, locations} ->
        suggestions = Enum.map(locations, fn loc ->
          %{
            value: loc.display_name,
            label: loc.display_name,
            country: loc.country,
            country_code: loc.country_code,
            coordinates: %{
              lat: get_coordinate(loc, :lat),
              lng: get_coordinate(loc, :lng)
            },
            specificity: calculate_specificity(loc)
          }
        end)
        |> Enum.sort_by(& &1.specificity, :desc)
        
        {:ok, suggestions}
        
      {:ok, location} ->
        {:ok, [%{
          value: location.display_name,
          label: location.display_name,  
          country: location.country,
          country_code: location.country_code,
          coordinates: %{
            lat: get_coordinate(location, :lat),
            lng: get_coordinate(location, :lng)
          },
          specificity: 1.0
        }]}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Enhanced search that includes disambiguation metadata in the response.
  Used by explore_results_controller for better user experience.
  """
  def enhanced_search(location_query, opts \\ []) do
    case disambiguate(location_query) do
      {:ok, location} ->
        # Single match - proceed normally with coordinate conversion
        enhanced_location = location
        |> Map.put(:lat, get_coordinate(location, :lat))
        |> Map.put(:lng, get_coordinate(location, :lng))
        {:ok, enhanced_location, %{disambiguation: :none, alternatives: []}}
        
      {:ambiguous, locations} ->
        # Multiple matches - use first one but provide alternatives
        primary = List.first(locations)
        alternatives = Enum.drop(locations, 1)
        
        Logger.info("🤔 Ambiguous location '#{location_query}' - using #{primary.display_name}, #{length(alternatives)} alternatives available")
        
        # Convert coordinates for primary location
        enhanced_primary = primary
        |> Map.put(:lat, get_coordinate(primary, :lat))
        |> Map.put(:lng, get_coordinate(primary, :lng))
        
        {:ok, enhanced_primary, %{
          disambiguation: :ambiguous,
          alternatives: alternatives,
          suggestion: "Did you mean #{primary.display_name}?"
        }}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp normalize_query(query) do
    query
    |> String.downcase()
    |> String.trim()
    # Remove redundant country/territory indicators
    |> String.replace(~r/,\s*(usa|united states|us)$/, "")
    |> String.replace(~r/[,\s]+/, " ")
  end

  defp is_specific_query?(query) do
    # Use lowercase only for matching, preserve original format for searching
    query_lower = String.downcase(query)
    
    # Check for country indicators
    country_indicators = [
      "puerto rico", "pr",
      "texas", "tx", "usa", "united states",
      "argentina", "mexico", "canada"
    ]
    
    # Check for state indicators (US states)
    us_states = [
      "alabama", "alaska", "arizona", "arkansas", "california", "colorado",
      "texas", "florida", "new york", "illinois", "pennsylvania"
    ]
    
    indicators = country_indicators ++ us_states
    Enum.any?(indicators, fn indicator ->
      String.contains?(query_lower, indicator)
    end)
  end

  defp find_specific_location(query) do
    # Try original query first
    case Places.search_cities(query, limit: 5) do
      {:ok, [location | _]} ->
        {:ok, location}
      {:ok, []} ->
        # Empty results, try normalized
        try_normalized_query(query)
      {:error, _reason} ->
        # Search failed, try normalized  
        try_normalized_query(query)
    end
  end

  defp try_normalized_query(query) do
    # Try normalized query (remove ", USA" etc.)
    normalized = String.replace(query, ~r/,\s*(usa|united states|us)$/i, "")
    if normalized != query do
      case Places.search_cities(normalized, limit: 5) do
        {:ok, [location | _]} ->
          {:ok, location}
        {:ok, []} ->
          # Database search failed, try Google geocoding as final fallback
          try_google_geocoding(query)
        {:error, _reason} ->
          # Database search failed, try Google geocoding as final fallback
          try_google_geocoding(query)
      end
    else
      # No normalization needed, try Google geocoding as final fallback
      try_google_geocoding(query)
    end
  end

  defp find_all_matches(normalized_query) do
    # Extract just the city name (first word/part)
    city_name = extract_city_name(normalized_query)
    
    # Search database for all cities with this name
    cities = from(c in City,
      where: ilike(c.name, ^"%#{city_name}%") or 
             ilike(c.normalized_name, ^"%#{city_name}%"),
      order_by: [
        desc: c.search_count,  # Popular cities first
        asc: c.country_code,   # Then by country
        asc: c.name
      ],
      limit: 10
    ) |> Repo.all()
    
    case cities do
      [] ->
        # No database matches, try Google geocoding as fallback
        Logger.info("🔍 No database matches for '#{normalized_query}', trying Google geocoding")
        try_google_geocoding(normalized_query)
      [single_city] ->
        {:ok, single_city}
      multiple_cities ->
        # Check if they're actually different locations
        unique_locations = deduplicate_locations(multiple_cities)
        
        case unique_locations do
          [single_location] -> {:ok, single_location}
          multiple_locations -> {:ambiguous, multiple_locations}
        end
    end
  end

  defp extract_city_name(query) do
    # Take first word/part before comma or space
    query
    |> String.split([",", " "])
    |> List.first()
    |> String.trim()
  end

  defp deduplicate_locations(cities) do
    # Group by name + country to remove duplicates
    cities
    |> Enum.group_by(fn city -> 
      "#{String.downcase(city.name)}_#{String.downcase(city.country)}"
    end)
    |> Enum.map(fn {_key, group} -> 
      # Take the one with most search activity
      Enum.max_by(group, & &1.search_count, fn -> List.first(group) end)
    end)
  end

  defp calculate_specificity(location) do
    # Higher specificity for more popular/well-known locations
    base_score = 0.5
    
    # Boost for search activity
    search_boost = min(location.search_count / 100, 0.3)
    
    # Boost for countries/territories with our data
    country_boost = case location.country_code do
      "pr" -> 0.2  # Puerto Rico - we have data
      "us" -> 0.1  # United States
      _ -> 0.0
    end
    
    base_score + search_boost + country_boost
  end

  # Helper function to extract coordinates from different data formats
  defp get_coordinate(location, coord_type) do
    cond do
      # Formatted result from Places.search_cities (has :lat/:lon already)
      Map.has_key?(location, coord_type) ->
        Map.get(location, coord_type)
      
      # Database struct format (has :latitude/:longitude as Decimal)
      coord_type == :lat and Map.has_key?(location, :latitude) ->
        if location.latitude, do: Decimal.to_float(location.latitude), else: nil
        
      coord_type == :lng and Map.has_key?(location, :longitude) ->
        if location.longitude, do: Decimal.to_float(location.longitude), else: nil
        
      # Handle :lon as alias for :lng
      coord_type == :lng and Map.has_key?(location, :lon) ->
        Map.get(location, :lon)
        
      true ->
        nil
    end
  end

  # Google geocoding fallback when database and LocationIQ searches fail
  defp try_google_geocoding(query) do
    Logger.info("🌍 Trying Google geocoding for: #{query}")
    
    # Determine country code and region from query for better results
    opts = determine_geocoding_opts(query)
    
    case GoogleGeocoding.geocode_and_store(query, opts) do
      {:ok, location} ->
        Logger.info("✅ Google geocoding success for '#{query}': #{location.display_name}")
        {:ok, location}
        
      {:error, reason} ->
        Logger.warn("❌ Google geocoding failed for '#{query}': #{inspect(reason)}")
        {:error, "No location found for: #{query}"}
    end
  end

  # Determine geocoding options based on query content
  defp determine_geocoding_opts(query) do
    query_lower = String.downcase(query)
    
    cond do
      # Puerto Rico queries
      String.contains?(query_lower, "puerto rico") or String.contains?(query_lower, ", pr") ->
        [country_code: "PR", region: "pr"]
        
      # US queries
      String.contains?(query_lower, "usa") or String.contains?(query_lower, "united states") ->
        [country_code: "US", region: "us"]
        
      # Default - no restrictions
      true ->
        []
    end
  end
end