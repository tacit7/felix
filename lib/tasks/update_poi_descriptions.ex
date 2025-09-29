defmodule Mix.Tasks.UpdatePoiDescriptions do
  @moduledoc """
  Updates POI descriptions using LocationIQ Places API.
  
  This task fetches detailed place information from LocationIQ for existing POIs
  in the database that have missing or generic descriptions, enriching them with
  better metadata and descriptions.

  ## Usage

      # Update all POIs with missing descriptions
      mix update_poi_descriptions

      # Update only POIs from specific addresses (partial match)
      mix update_poi_descriptions --addresses="Austin,Dallas"

      # Limit number of POIs to process (useful for testing)
      mix update_poi_descriptions --limit=10

      # Force update even if POI already has description
      mix update_poi_descriptions --force

      # Dry run - show what would be updated without making changes
      mix update_poi_descriptions --dry-run

  ## Options

    * `--addresses` - Comma-separated list of address keywords to process (optional)
    * `--limit` - Maximum number of POIs to process (optional)
    * `--force` - Update POIs even if they already have descriptions (optional)
    * `--dry-run` - Show what would be updated without making changes (optional)
    * `--verbose` - Show detailed progress information (optional)

  """

  use Mix.Task

  alias RouteWiseApi.{Repo, LocationIQ}
  alias RouteWiseApi.Trips.POI
  import Ecto.Query

  require Logger

  @shortdoc "Updates POI descriptions using LocationIQ Places API"

  def run(args) do
    Mix.Task.run("app.start")

    options = parse_options(args)
    
    IO.puts("\n🔍 POI Description Update Task (LocationIQ)")
    IO.puts("==========================================")
    
    if options[:dry_run] do
      IO.puts("🌡️  DRY RUN MODE - No changes will be made\n")
    end

    pois = get_pois_to_update(options)
    
    IO.puts("📊 Found #{length(pois)} POIs to process")
    
    if length(pois) == 0 do
      IO.puts("✅ No POIs need description updates!")
    else
      unless options[:dry_run] do
        IO.puts("🚀 Starting LocationIQ description updates...")
        IO.puts("⚠️  Note: This will make API calls and may hit rate limits\n")
      end

      # Process POIs in batches to respect rate limits
      batch_size = 5

      pois
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index()
      |> Enum.reduce(0, fn {batch, batch_index}, acc ->
        IO.puts("📦 Processing batch #{batch_index + 1}/#{div(length(pois), batch_size) + 1}")
        
        batch_updated = process_poi_batch(batch, options)
        
        # Add delay between batches to respect rate limits
        unless options[:dry_run] do
          if batch_index < div(length(pois), batch_size) do
            IO.puts("⏳ Waiting 2 seconds before next batch...")
            Process.sleep(2000)
          end
        end
        
        acc + batch_updated
      end)
      |> then(fn total ->
        IO.puts("\n✅ Task completed!")
        IO.puts("📈 Total POIs updated: #{total}")
        
        if total > 0 and not options[:dry_run] do
          IO.puts("💡 Tip: Clear your cache to see updated descriptions")
          IO.puts("   Run: mix cache.clear")
        end
      end)
    end
  end

  defp parse_options(args) do
    {opts, _} = OptionParser.parse!(args,
      strict: [
        addresses: :string,
        limit: :integer,
        force: :boolean,
        dry_run: :boolean,
        verbose: :boolean
      ]
    )

    opts
  end

  defp get_pois_to_update(options) do
    base_query = from p in POI, 
      where: not is_nil(p.latitude) and not is_nil(p.longitude),
      order_by: [desc: p.updated_at]

    # Filter by missing descriptions unless force is specified
    query_with_descriptions = if options[:force] do
      base_query
    else
      from p in base_query,
        where: is_nil(p.description) or 
               p.description == "" or 
               fragment("? LIKE '%★%'", p.description) or
               fragment("? LIKE '%Point of interest%'", p.description) # Generic descriptions
    end

    # Filter by addresses if specified
    query_with_addresses = case options[:addresses] do
      nil -> query_with_descriptions
      addresses_string ->
        keywords = String.split(addresses_string, ",") |> Enum.map(&String.trim/1)
        # Use OR conditions to match any keyword in the address
        from p in query_with_descriptions,
          where: fragment("LOWER(?) LIKE ANY(?)", p.address, 
            ^Enum.map(keywords, &("%#{String.downcase(&1)}%")))
    end

    # Apply limit if specified
    final_query = case options[:limit] do
      nil -> query_with_addresses
      limit -> from p in query_with_addresses, limit: ^limit
    end

    Repo.all(final_query)
  end

  defp process_poi_batch(pois, options) do
    pois
    |> Enum.map(&process_single_poi(&1, options))
    |> Enum.count(fn result -> result == :updated end)
  end

  defp process_single_poi(poi, options) do
    if options[:verbose] do
      current_desc = if poi.description && poi.description != "" do
        String.slice(poi.description, 0..50) <> "..."
      else
        "No description"
      end
      
      # Extract city from address for display
      address_city = extract_city_from_address(poi.address)
      IO.puts("  🔍 #{poi.name} (#{address_city}) - Current: #{current_desc}")
    end

    if options[:dry_run] do
      address_city = extract_city_from_address(poi.address)
      IO.puts("  📝 Would update: #{poi.name} in #{address_city}")
      :would_update
    else
      update_poi_description(poi, options)
    end
  end

  defp update_poi_description(poi, options) do
    # Try to find place using name and location
    location = %{lat: poi.latitude, lng: poi.longitude}
    
    case LocationIQ.search_places(poi.name, location, limit: 1, radius: 1000) do
      {:ok, [place | _]} ->
        # Update POI with LocationIQ description and data
        attrs = %{
          description: place.description,
          categories: [place.category] # Update category if available
        }
        
        case update_poi(poi, attrs) do
          {:ok, updated_poi} ->
            if options[:verbose] do
              IO.puts("  ✅ Updated: #{updated_poi.name}")
              IO.puts("      New description: #{updated_poi.description}")
            else
              IO.puts("  ✅ #{poi.name}")
            end
            :updated

          {:error, changeset} ->
            IO.puts("  ❌ Failed to update #{poi.name}: #{inspect(changeset.errors)}")
            :failed
        end

      {:ok, []} ->
        if options[:verbose] do
          IO.puts("  ⚠️  No LocationIQ match found for #{poi.name}")
        end
        :no_match

      {:error, reason} ->
        IO.puts("  ⚠️  LocationIQ API error for #{poi.name}: #{reason}")
        :api_error
    end
  rescue
    error ->
      IO.puts("  ❌ Exception updating #{poi.name}: #{Exception.message(error)}")
      :exception
  end

  defp update_poi(poi, attrs) do
    poi
    |> POI.changeset(attrs)
    |> Repo.update()
  end

  defp extract_city_from_address(address) when is_binary(address) do
    # Simple extraction - get the part after the first comma or return "Unknown"
    case String.split(address, ",") do
      [_street, city_state | _] -> 
        city_state 
        |> String.trim() 
        |> String.split(" ") 
        |> hd()
      _ -> 
        "Unknown"
    end
  end
  defp extract_city_from_address(_), do: "Unknown"
end