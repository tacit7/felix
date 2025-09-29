defmodule Mix.Tasks.AutoScrapePlaces do
  @moduledoc """
  Automatically scrape TripAdvisor data for cities that don't have enough place data.
  
  Usage:
    mix auto_scrape_places "Austin, TX"
    mix auto_scrape_places "Miami, FL" --min-places 20
    mix auto_scrape_places "Portland, OR" --type restaurants
    mix auto_scrape_places --check-all --min-places 15
  """
  
  use Mix.Task
  import Ecto.Query, warn: false
  require Logger
  alias RouteWiseApi.{Places, Repo}
  alias RouteWiseApi.Places.Place

  @shortdoc "Auto-scrape TripAdvisor data for cities with insufficient place data"

  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, remaining, _} = OptionParser.parse(args, 
      switches: [
        min_places: :integer,
        type: :string,
        check_all: :boolean,
        force: :boolean,
        dry_run: :boolean
      ],
      aliases: [m: :min_places, t: :type, c: :check_all, f: :force, d: :dry_run]
    )
    
    min_places = Keyword.get(opts, :min_places, 10)
    scrape_type = Keyword.get(opts, :type, "all") # all, restaurants, attractions
    check_all = Keyword.get(opts, :check_all, false)
    force = Keyword.get(opts, :force, false)
    dry_run = Keyword.get(opts, :dry_run, false)
    
    cond do
      check_all ->
        check_all_cities(min_places, scrape_type, dry_run)
      
      length(remaining) > 0 ->
        city_query = hd(remaining)
        scrape_city(city_query, min_places, scrape_type, force, dry_run)
      
      true ->
        Mix.shell().info("Usage: mix auto_scrape_places \"City Name\" [options]")
        Mix.shell().info("   or: mix auto_scrape_places --check-all")
        Mix.shell().info("")
        Mix.shell().info("Options:")
        Mix.shell().info("  --min-places N    Minimum places before scraping (default: 10)")
        Mix.shell().info("  --type TYPE       What to scrape: all|restaurants|attractions")
        Mix.shell().info("  --check-all       Check all cities in database")
        Mix.shell().info("  --force           Force scrape even if city has enough places")
        Mix.shell().info("  --dry-run         Show what would be scraped without doing it")
    end
  end
  
  defp check_all_cities(min_places, scrape_type, dry_run) do
    Mix.shell().info("🔍 Checking all cities for insufficient place data...")
    
    # Get unique cities from existing places using formatted_address
    cities_query = """
    SELECT DISTINCT 
      COALESCE(formatted_address, 'Unknown') as city,
      'Unknown' as state_country,
      COUNT(*) as place_count
    FROM places 
    WHERE formatted_address IS NOT NULL 
    GROUP BY formatted_address
    HAVING COUNT(*) < $1
    ORDER BY place_count ASC
    """
    
    case Repo.query(cities_query, [min_places]) do
      {:ok, %{rows: rows}} ->
        cities_to_scrape = Enum.map(rows, fn [city, state_country, count] ->
          %{city: city, state_country: state_country, current_count: count}
        end)
        
        if length(cities_to_scrape) == 0 do
          Mix.shell().info("✅ All cities have sufficient place data (≥#{min_places} places)")
        else
          Mix.shell().info("📊 Found #{length(cities_to_scrape)} cities needing more data:")
          
          Enum.each(cities_to_scrape, fn %{city: city, state_country: state, current_count: count} ->
            location = if state != "", do: "#{city}, #{state}", else: city
            Mix.shell().info("  #{location}: #{count} places (need #{min_places - count} more)")
          end)
          
          if not dry_run do
            Mix.shell().info("")
            Mix.shell().info("🚀 Starting auto-scraping...")
            
            Enum.each(cities_to_scrape, fn %{city: city, state_country: state} ->
              location_query = if state != "", do: "#{city}, #{state}", else: city
              scrape_city(location_query, min_places, scrape_type, false, false)
              
              # Delay between cities to be respectful
              :timer.sleep(10_000) # 10 second delay
            end)
          end
        end
        
      {:error, error} ->
        Mix.shell().error("❌ Database error: #{inspect(error)}")
    end
  end
  
  defp scrape_city(city_query, min_places, scrape_type, force, dry_run) do
    Mix.shell().info("🎯 Processing: #{city_query}")
    
    # Parse city and state/country
    {city, state} = parse_location(city_query)
    
    # Check current place count
    current_count = count_existing_places(city, state)
    
    should_scrape = force or current_count < min_places
    
    Mix.shell().info("📊 Current places in database: #{current_count}")
    
    if should_scrape do
      if current_count < min_places do
        Mix.shell().info("⚠️ Below minimum threshold (#{min_places}), scraping needed")
      else
        Mix.shell().info("🔄 Force scraping requested")
      end
      
      if dry_run do
        Mix.shell().info("🔍 DRY RUN: Would scrape #{scrape_type} for #{city_query}")
      else
        Mix.shell().info("🚀 Starting TripAdvisor scrape...")
        run_python_scraper(city, state, scrape_type, city_query)
      end
    else
      Mix.shell().info("✅ #{city_query} has sufficient data (#{current_count} ≥ #{min_places})")
    end
  end
  
  defp parse_location(city_query) do
    case String.split(city_query, ",", parts: 2) do
      [city] -> 
        {String.trim(city), ""}
      [city, state] -> 
        {String.trim(city), String.trim(state)}
    end
  end
  
  defp count_existing_places(city, state) do
    query = from(p in Place, where: ilike(p.formatted_address, ^"%#{city}%"))
    
    query = if state != "" do
      from(p in query, where: ilike(p.formatted_address, ^"%#{state}%"))
    else
      query
    end
    
    Repo.aggregate(query, :count, :id)
  end
  
  defp run_python_scraper(city, state, scrape_type, city_query) do
    scraper_path = Path.join([
      File.cwd!(), 
      "scraper", 
      "universal_city_scraper.py"
    ])
    
    # Build command arguments
    args = [
      "python3", scraper_path,
      city
    ]
    
    args = if state != "", do: args ++ ["--state", state], else: args
    args = args ++ ["--type", scrape_type]
    
    Mix.shell().info("🐍 Running: #{Enum.join(args, " ")}")
    
    case System.cmd("python3", tl(args), stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info("✅ Python scraper completed successfully")
        
        # Find the generated JSON file
        output_lines = String.split(output, "\n")
        json_file = Enum.find_value(output_lines, fn line ->
          if String.contains?(line, "Saved to:") do
            line |> String.split("Saved to:") |> List.last() |> String.trim()
          end
        end)
        
        if json_file do
          Mix.shell().info("📄 Scraper output: #{json_file}")
          import_scraped_data(json_file, city_query)
        else
          Mix.shell().info("📊 Scraper output:")
          Mix.shell().info(output)
        end
      
      {output, exit_code} ->
        Mix.shell().error("❌ Python scraper failed (exit code: #{exit_code})")
        Mix.shell().error("Output: #{output}")
    end
  end
  
  defp import_scraped_data(json_file, city_query) do
    Mix.shell().info("📥 Importing scraped data from #{json_file}")
    
    case File.read(json_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            process_scraped_data(data, city_query)
            
            # Clean up JSON file after import
            File.rm(json_file)
            Mix.shell().info("🧹 Cleaned up temporary file")
            
          {:error, error} ->
            Mix.shell().error("❌ JSON parsing error: #{inspect(error)}")
        end
      
      {:error, error} ->
        Mix.shell().error("❌ File read error: #{inspect(error)}")
    end
  end
  
  defp process_scraped_data(data, city_query) do
    restaurants = Map.get(data, "restaurants", [])
    attractions = Map.get(data, "attractions", [])
    
    total_imported = 0
    
    # Import restaurants
    if length(restaurants) > 0 do
      Mix.shell().info("🍽️ Importing #{length(restaurants)} restaurants...")
      restaurant_count = import_places(restaurants, "restaurant")
      total_imported = total_imported + restaurant_count
    end
    
    # Import attractions  
    if length(attractions) > 0 do
      Mix.shell().info("🎯 Importing #{length(attractions)} attractions...")
      attraction_count = import_places(attractions, "tourist_attraction")
      total_imported = total_imported + attraction_count
    end
    
    Mix.shell().info("✅ Imported #{total_imported} places for #{city_query}")
  end
  
  defp import_places(places_data, default_type) do
    imported_count = 0
    
    Enum.each(places_data, fn place_data ->
      coords = Map.get(place_data, "coordinates", %{})
      lat = Map.get(coords, "lat")
      lng = Map.get(coords, "lng")
      address = Map.get(place_data, "address", "")
      name = Map.get(place_data, "name")
      
      # If coordinates are missing, try to geocode using LocationIQ
      {final_lat, final_lng} = if lat && lng do
        {lat, lng}
      else
        Logger.info("🌐 Geocoding #{name} using address: #{address}")
        geocode_place_address(name, address)
      end
      
      if final_lat && final_lng do
        tripadvisor_url = Map.get(place_data, "tripadvisor_url")
        full_tripadvisor_url = if tripadvisor_url && String.starts_with?(tripadvisor_url, "/") do
          "https://www.tripadvisor.com" <> tripadvisor_url
        else
          tripadvisor_url
        end
        
        place_attrs = %{
          name: name,
          google_place_id: "tripadvisor_" <> to_string(Map.get(place_data, "location_id", "")),
          latitude: Decimal.new(to_string(final_lat)),
          longitude: Decimal.new(to_string(final_lng)),
          formatted_address: address,
          phone_number: nil,
          website: full_tripadvisor_url,
          categories: [default_type],
          rating: Decimal.new("4.0"),
          reviews_count: 100,
          price_level: nil,
          opening_hours: nil,
          photos: [],
          cached_at: DateTime.utc_now(),
          tripadvisor_url: full_tripadvisor_url
        }
        
        case Places.create_place(place_attrs) do
          {:ok, _place} ->
            imported_count = imported_count + 1
            Logger.info("✅ Imported: #{name}")
          
          {:error, changeset} ->
            Logger.warn("❌ Failed to import #{name}: #{inspect(changeset.errors)}")
        end
      else
        Logger.warn("⚠️ Skipping #{name} - no coordinates available")
      end
    end)
    
    imported_count
  end
  
  defp geocode_place_address(name, address) do
    # Use LocationIQ to geocode the address
    case RouteWiseApi.LocationIQ.geocode(address) do
      {:ok, results} when is_list(results) and length(results) > 0 ->
        result = hd(results)
        lat = result["lat"] |> String.to_float()
        lng = result["lon"] |> String.to_float()
        Logger.info("📍 Found coordinates for #{name}: #{lat}, #{lng}")
        {lat, lng}
      
      {:ok, result} when is_map(result) ->
        lat = result["lat"] |> String.to_float()
        lng = result["lon"] |> String.to_float()
        Logger.info("📍 Found coordinates for #{name}: #{lat}, #{lng}")
        {lat, lng}
      
      {:error, reason} ->
        Logger.warn("🚫 Geocoding failed for #{name}: #{inspect(reason)}")
        {nil, nil}
      
      _ ->
        Logger.warn("🚫 Unexpected geocoding response for #{name}")
        {nil, nil}
    end
  rescue
    error ->
      Logger.warn("🚫 Geocoding error for #{name}: #{inspect(error)}")
      {nil, nil}
  end
end