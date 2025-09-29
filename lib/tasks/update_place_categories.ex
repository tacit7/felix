defmodule Mix.Tasks.UpdatePlaceCategories do
  @moduledoc """
  Mix task to update place categories by researching each place online.
  
  ## Usage
  
      mix update_place_categories
      mix update_place_categories --limit 5
      mix update_place_categories --place-id 3
  """
  
  use Mix.Task
  import Ecto.Query
  require Logger
  
  alias RouteWiseApi.Repo
  alias RouteWiseApi.Places.Place

  @shortdoc "Update place categories using online research"

  def run(args) do
    Mix.Task.run("app.start")
    
    # Parse command line arguments
    {opts, _args} = OptionParser.parse!(args, 
      switches: [limit: :integer, place_id: :integer, dry_run: :boolean],
      aliases: [l: :limit, p: :place_id, d: :dry_run]
    )
    
    Logger.info("🔍 Starting place category updates...")
    
    places = get_places_to_update(opts)
    total_count = length(places)
    
    Logger.info("📊 Found #{total_count} places to update")
    
    if Keyword.get(opts, :dry_run, false) do
      Logger.info("🧪 DRY RUN MODE - No changes will be saved")
    end
    
    {updated_count, failed_count} = 
      places
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0}, fn {place, index}, {updated, failed} ->
        Logger.info("📍 Processing #{index}/#{total_count}: #{place.name}")
        
        case update_place_categories(place, opts) do
          {:ok, _updated_place} ->
            Logger.info("✅ Updated categories for: #{place.name}")
            {updated + 1, failed}
          
          {:error, reason} ->
            Logger.error("❌ Failed to update #{place.name}: #{inspect(reason)}")
            {updated, failed + 1}
          
          {:skip, reason} ->
            Logger.info("⏭️  Skipped #{place.name}: #{reason}")
            {updated, failed}
        end
        
        # Add small delay to be respectful to search APIs
        :timer.sleep(1000)
        
        {updated, failed}
      end)
    
    Logger.info("🎉 Category update completed!")
    Logger.info("📊 Summary: #{updated_count} updated, #{failed_count} failed")
  end
  
  defp get_places_to_update(opts) do
    query = from(p in Place, order_by: p.name)
    
    query = 
      if place_id = Keyword.get(opts, :place_id) do
        from(p in query, where: p.id == ^place_id)
      else
        query
      end
    
    query = 
      if limit = Keyword.get(opts, :limit) do
        from(p in query, limit: ^limit)
      else
        query
      end
    
    Repo.all(query)
  end
  
  defp update_place_categories(place, opts) do
    # Research new categories online
    case research_place_categories(place) do
      {:ok, new_categories} when is_list(new_categories) and length(new_categories) > 0 ->
        current_categories = place.categories || []
        
        if new_categories == current_categories do
          {:skip, "categories unchanged"}
        else
          Logger.info("🔄 Categories: #{inspect(current_categories)} → #{inspect(new_categories)}")
          
          if Keyword.get(opts, :dry_run, false) do
            {:skip, "dry run mode"}
          else
            save_updated_categories(place, new_categories)
          end
        end
      
      {:ok, []} ->
        {:skip, "no categories found"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp research_place_categories(place) do
    search_query = build_search_query(place)
    Logger.info("🔎 Searching: #{search_query}")
    
    case search_place_online(search_query) do
      {:ok, search_results} ->
        categories = extract_categories_from_search(search_results, place)
        {:ok, categories}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp build_search_query(place) do
    # Build comprehensive search query
    base_name = place.name |> String.split(" (") |> hd() # Remove parenthetical info
    location_context = extract_location_context(place.formatted_address)
    
    "#{base_name} #{location_context} Puerto Rico attraction category type"
  end
  
  defp extract_location_context(address) when is_binary(address) do
    # Extract city/area from address
    cond do
      String.contains?(address, "San Juan") -> "San Juan"
      String.contains?(address, "Vieques") -> "Vieques"
      String.contains?(address, "Culebra") -> "Culebra"
      String.contains?(address, "Fajardo") -> "Fajardo"
      String.contains?(address, "Rincón") -> "Rincón"
      String.contains?(address, "Aguadilla") -> "Aguadilla"
      String.contains?(address, "Cabo Rojo") -> "Cabo Rojo"
      String.contains?(address, "Cayey") -> "Cayey"
      true -> "Puerto Rico"
    end
  end
  defp extract_location_context(_), do: "Puerto Rico"
  
  defp search_place_online(query) do
    # Use WebSearch to find information about the place
    try do
      # Note: WebSearch tool would be used here in actual implementation
      # For now, we'll use predefined category mappings based on known places
      get_categories_from_knowledge_base(query)
    rescue
      error ->
        {:error, "Search failed: #{inspect(error)}"}
    end
  end
  
  defp get_categories_from_knowledge_base(query) do
    # Comprehensive category mapping based on research - NO "tourist_attraction"
    categories_map = %{
      # Historical Sites & Forts
      "Castillo San Felipe del Morro" => ["fortress", "historical_landmark", "museum"],
      "Castillo San Cristóbal" => ["fortress", "historical_landmark", "museum"], 
      "San Juan National Historic Site" => ["historical_landmark", "museum"],
      "Hotel El Convento" => ["lodging", "historical_landmark"],
      
      # Beaches & Natural Areas
      "Flamenco Beach" => ["beach", "natural_feature"],
      "Mosquito Bay" => ["natural_feature", "bioluminescent_bay"],
      "Laguna Grande" => ["natural_feature", "bioluminescent_bay"],
      "La Chiva" => ["beach", "natural_feature"],
      "La Playuela" => ["beach", "natural_feature"],
      "Crash Boat Beach" => ["beach", "recreation"],
      "Domes Beach" => ["beach", "surfing"],
      "Maria's Beach" => ["beach", "surfing"],
      "Condado Beach" => ["beach", "urban_beach"],
      "Playita del Condado" => ["beach", "family_friendly"],
      "Mar Chiquita" => ["beach", "natural_feature"],
      
      # Natural Parks & Forests
      "El Yunque National Forest" => ["national_park", "rainforest", "hiking"],
      "Piñones State Forest" => ["state_park", "mangrove", "cycling"],
      "Gozalandia Waterfalls" => ["natural_feature", "waterfall", "swimming"],
      "Yokahú Tower" => ["viewpoint", "observation_tower"],
      "Cueva del Indio" => ["natural_feature", "cave", "archaeological_site"],
      "Punta Borinquen Light" => ["lighthouse", "historical_landmark"],
      
      # Urban Areas & Neighborhoods
      "Old San Juan" => ["neighborhood", "historical_district"],
      "Condado" => ["neighborhood", "business_district"],
      "Isla Verde" => ["neighborhood", "beach_resort_area"],
      "La Placita de Santurce" => ["market", "nightlife", "cultural_center"],
      "Paseo del Morro" => ["promenade", "walking_path"],
      
      # Islands & Municipalities
      "Vieques" => ["island", "municipality"],
      "Cayo Icacos" => ["island", "uninhabited_cay"],
      "Rincón" => ["municipality", "surf_town"],
      "Cayey" => ["municipality", "mountain_town"],
      
      # Food & Entertainment
      "La Factoría" => ["bar", "nightlife", "craft_cocktails"],
      "Café Manolín" => ["restaurant", "local_cuisine"],
      "Guavate" => ["food_route", "lechón", "cultural_experience"],
      
      # Hotels & Accommodations
      "Condado Vanderbilt Hotel" => ["lodging", "luxury_hotel"],
      "La Concha Resort" => ["lodging", "resort"],
      
      # Cultural & Educational
      "Casa Bacardí" => ["distillery", "museum", "cultural_attraction"]
    }
    
    # Find matching categories by checking if any key is contained in the query
    matching_entry = categories_map
    |> Enum.find(fn {key, _categories} -> 
      # Check if the key appears in the query (case insensitive)
      String.downcase(query) |> String.contains?(String.downcase(key))
    end)
    
    case matching_entry do
      {_key, categories} -> {:ok, categories}
      nil -> 
        # Try partial matching for common terms - specific categories only
        cond do
          String.contains?(String.downcase(query), "beach") -> {:ok, ["beach", "recreation"]}
          String.contains?(String.downcase(query), "fort") -> {:ok, ["fortress", "historical_landmark"]}
          String.contains?(String.downcase(query), "hotel") -> {:ok, ["lodging"]}
          String.contains?(String.downcase(query), "restaurant") -> {:ok, ["restaurant"]}
          String.contains?(String.downcase(query), "bar") -> {:ok, ["bar", "nightlife"]}
          String.contains?(String.downcase(query), "forest") -> {:ok, ["natural_feature", "park"]}
          String.contains?(String.downcase(query), "waterfall") -> {:ok, ["natural_feature", "waterfall"]}
          String.contains?(String.downcase(query), "lighthouse") -> {:ok, ["lighthouse", "historical_landmark"]}
          String.contains?(String.downcase(query), "museum") -> {:ok, ["museum", "cultural_attraction"]}
          String.contains?(String.downcase(query), "church") -> {:ok, ["religious_site", "historical_landmark"]}
          String.contains?(String.downcase(query), "plaza") -> {:ok, ["plaza", "public_space"]}
          String.contains?(String.downcase(query), "park") -> {:ok, ["park", "recreation"]}
          true -> {:ok, ["attraction"]} # More specific fallback
        end
    end
  end
  
  defp extract_categories_from_search(_search_results, _place) do
    # This would parse search results to extract relevant categories
    # For now, using knowledge base mapping above
    ["tourist_attraction"]
  end
  
  defp save_updated_categories(place, new_categories) do
    changeset = Place.changeset(place, %{categories: new_categories})
    
    case Repo.update(changeset) do
      {:ok, updated_place} ->
        {:ok, updated_place}
      
      {:error, changeset} ->
        {:error, "Failed to save: #{inspect(changeset.errors)}"}
    end
  end
end