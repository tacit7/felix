defmodule Mix.Tasks.DebugPois do
  use Mix.Task

  @shortdoc "Debug POI address issue by tracing the data flow"

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("🔍 Debugging POI address issue...")
    
    # Test the Places service directly
    IO.puts("\n1️⃣ Testing PlacesService.find_places_by_type...")
    
    midpoint = %{lat: 31.51, lng: -97.12}  # Austin-Dallas midpoint
    
    case RouteWiseApi.PlacesService.find_places_by_type(midpoint, "tourist_attraction", radius: 25000) do
      {:ok, places} ->
        IO.puts("✅ Found #{length(places)} places")
        
        if length(places) > 0 do
          first_place = hd(places)
          IO.puts("\n🔬 First place analysis:")
          IO.puts("  Name: #{Map.get(first_place, :name)}")
          IO.puts("  Struct type: #{first_place.__struct__}")
          IO.puts("  Available fields: #{inspect(Map.keys(first_place))}")
          IO.puts("  formatted_address: #{Map.get(first_place, :formatted_address, "MISSING")}")
          IO.puts("  address: #{Map.get(first_place, :address, "MISSING")}")
          IO.puts("  google_place_id: #{Map.get(first_place, :google_place_id)}")
        end
        
      {:error, reason} ->
        IO.puts("❌ PlacesService failed: #{reason}")
    end

    # Test the Trips context
    IO.puts("\n2️⃣ Testing Trips.list_pois_for_route...")
    
    case RouteWiseApi.Trips.list_pois_for_route("Austin", "Dallas") do
      {:ok, pois} ->
        IO.puts("✅ Found #{length(pois)} POIs from route function")
        
        if length(pois) > 0 do
          first_poi = hd(pois)
          IO.puts("\n🔬 First POI analysis:")
          IO.puts("  Name: #{Map.get(first_poi, :name)}")
          IO.puts("  Struct type: #{first_poi.__struct__}")
          IO.puts("  Available fields: #{inspect(Map.keys(first_poi))}")
          IO.puts("  formatted_address: #{Map.get(first_poi, :formatted_address, "MISSING")}")
          IO.puts("  address: #{Map.get(first_poi, :address, "MISSING")}")
        end
        
      {:error, reason} ->
        IO.puts("❌ Trips POI route failed: #{reason}")
    end
    
    IO.puts("\n✅ Debug complete!")
  end
end