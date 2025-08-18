defmodule Mix.Tasks.PopulateTripadvisorUrls do
  @moduledoc """
  Populates places table with TripAdvisor URLs from scraping data.
  """
  use Mix.Task

  alias RouteWiseApi.{Repo, Places}
  alias RouteWiseApi.Places.Place

  require Logger

  @shortdoc "Populate places with TripAdvisor URLs from scraping data"

  def run(_args) do
    Mix.Task.run("app.start")
    
    Logger.info("🎯 Starting TripAdvisor URL population...")
    
    # Load the comprehensive scraping data
    tripadvisor_data = load_tripadvisor_data()
    
    if tripadvisor_data do
      populate_urls_from_data(tripadvisor_data)
    else
      Logger.error("❌ No TripAdvisor scraping data found")
    end
  end

  defp load_tripadvisor_data() do
    # Try to load the comprehensive scraping data
    file_path = Path.join([
      File.cwd!(), 
      "scraper", 
      "isla_verde_final_comprehensive_1755100897.json"
    ])
    
    if File.exists?(file_path) do
      case File.read!(file_path) |> Jason.decode() do
        {:ok, data} -> 
          Logger.info("✅ Loaded TripAdvisor data with #{length(data["attractions"])} attractions")
          data
        {:error, reason} -> 
          Logger.error("❌ Failed to parse TripAdvisor data: #{inspect(reason)}")
          nil
      end
    else
      Logger.error("❌ TripAdvisor data file not found at: #{file_path}")
      nil
    end
  end

  defp populate_urls_from_data(%{"attractions" => attractions}) do
    Logger.info("🔄 Processing #{length(attractions)} TripAdvisor attractions...")
    
    updated_count = 0
    matched_count = 0
    
    {updated_count, matched_count} = Enum.reduce(attractions, {0, 0}, fn attraction, {updated_acc, matched_acc} ->
      tripadvisor_url = attraction["tripadvisor_url"]
      attraction_name = attraction["name"]
      
      if tripadvisor_url && String.starts_with?(tripadvisor_url, "/") do
        # Convert relative URL to full URL
        full_url = "https://www.tripadvisor.com" <> tripadvisor_url
        
        # Try to find matching place by name (fuzzy matching)
        case find_matching_place(attraction_name) do
          %Place{} = place ->
            case update_place_tripadvisor_url(place, full_url) do
              {:ok, _updated_place} ->
                Logger.info("✅ Updated #{attraction_name} with TripAdvisor URL")
                {updated_acc + 1, matched_acc + 1}
              {:error, reason} ->
                Logger.error("❌ Failed to update #{attraction_name}: #{inspect(reason)}")
                {updated_acc, matched_acc + 1}
            end
          nil ->
            Logger.info("⚠️  No matching place found for: #{attraction_name}")
            {updated_acc, matched_acc}
        end
      else
        Logger.warn("⚠️  No valid TripAdvisor URL for: #{attraction_name}")
        {updated_acc, matched_acc}
      end
    end)
    
    Logger.info("📊 Population completed:")
    Logger.info("   • Total attractions processed: #{length(attractions)}")
    Logger.info("   • Places matched: #{matched_count}")
    Logger.info("   • Places updated: #{updated_count}")
    Logger.info("   • Success rate: #{if matched_count > 0, do: Float.round(updated_count / matched_count * 100, 1), else: 0}%")
  end

  defp find_matching_place(attraction_name) do
    # Try exact name match first
    case Repo.get_by(Place, name: attraction_name) do
      %Place{} = place -> 
        place
      nil ->
        # Try fuzzy matching by removing common words and normalizing
        normalized_name = normalize_name_for_matching(attraction_name)
        
        Places.list_places()
        |> Enum.find(fn place ->
          place_normalized = normalize_name_for_matching(place.name)
          String.jaro_distance(normalized_name, place_normalized) > 0.8
        end)
    end
  end

  defp normalize_name_for_matching(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")  # Remove punctuation
    |> String.replace(~r/\b(national|forest|beach|bay|cave|caves|puerto|rico|tour|with|and|the|of|at|in)\b/, "")  # Remove common words
    |> String.replace(~r/\s+/, " ")  # Normalize whitespace
    |> String.trim()
  end

  defp update_place_tripadvisor_url(%Place{} = place, tripadvisor_url) do
    place
    |> Place.changeset(%{tripadvisor_url: tripadvisor_url})
    |> Repo.update()
  end
end