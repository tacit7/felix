defmodule Mix.Tasks.FixEmptyAddresses do
  use Mix.Task
  import Ecto.Query
  alias RouteWiseApi.{Repo, Places}
  alias RouteWiseApi.Places.Place

  @shortdoc "Fix Place records with empty formatted_address fields"

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("🔧 Fixing Place records with empty addresses...")
    
    # Find all places with empty or null formatted_address
    empty_address_places = 
      from(p in Place,
        where: is_nil(p.formatted_address) or p.formatted_address == ""
      )
      |> Repo.all()
    
    count = length(empty_address_places)
    IO.puts("📊 Found #{count} places with empty addresses")
    
    if count == 0 do
      IO.puts("✅ No places need fixing")
    else
      IO.puts("🗑️ Deleting places with empty addresses to force fresh API calls...")
      
      # Delete these records so they'll be fetched fresh from Google Places API
      {deleted_count, _} = 
        from(p in Place,
          where: is_nil(p.formatted_address) or p.formatted_address == ""
        )
        |> Repo.delete_all()
      
      IO.puts("✅ Deleted #{deleted_count} stale place records")
      IO.puts("💡 Next API call will fetch fresh data with addresses from Google Places")
    end
    
    # Also clear the cache to ensure fresh fetches
    IO.puts("🧹 Clearing cache...")
    RouteWiseApi.Caching.clear_all_cache()
    IO.puts("✅ Cache cleared")
    
    IO.puts("\n🎯 Fix complete! Next route-results API call will fetch fresh POI data with addresses.")
  end
end