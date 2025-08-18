defmodule Mix.Tasks.DebugRoutePois do
  use Mix.Task

  @shortdoc "Debug why route POIs are returning NYC data instead of Austin-Dallas"

  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("🔍 Debugging route POI fetching...")
    
    # Test the full route POI flow
    case RouteWiseApi.Trips.list_pois_for_route("Austin", "Dallas") do
      {:ok, pois} ->
        IO.puts("✅ Got #{length(pois)} POIs")
        
        IO.puts("\n📍 POI Locations:")
        Enum.each(pois, fn poi ->
          lat = Map.get(poi, :latitude) || Map.get(poi, :lat)
          lng = Map.get(poi, :longitude) || Map.get(poi, :lng) || Map.get(poi, :lon)
          struct_type = poi.__struct__
          IO.puts("  #{Map.get(poi, :name)} | #{lat}, #{lng} | Struct: #{struct_type}")
        end)
        
        # Check if these are database POIs (fallback) or API POIs
        first_poi = hd(pois)
        if first_poi.id in [1, 2, 3] do
          IO.puts("\n⚠️  WARNING: These are database fallback POIs (test data)")
          IO.puts("   This means the route POI fetching failed")
        else
          IO.puts("\n✅ These are fresh API POIs")
        end
        
      {:error, reason} ->
        IO.puts("❌ Route POI fetching completely failed: #{reason}")
    end

    IO.puts("\n🧪 Testing individual components:")
    
    # Test geocoding
    IO.puts("\n1️⃣ Testing LocationIQ geocoding...")
    case RouteWiseApi.LocationIQ.autocomplete_cities("Austin", limit: 1) do
      {:ok, [city | _]} ->
        lat = Map.get(city, :lat) || Map.get(city, :latitude)
        lng = Map.get(city, :lon) || Map.get(city, :longitude)
        IO.puts("✅ Austin coordinates: #{lat}, #{lng}")
      {:error, reason} ->
        IO.puts("❌ LocationIQ geocoding failed: #{reason}")
    end
    
    # Test Places service directly
    IO.puts("\n2️⃣ Testing PlacesService with Austin-Dallas midpoint...")
    midpoint = %{lat: 31.51, lng: -97.12}
    
    case RouteWiseApi.PlacesService.find_places_by_type(midpoint, "restaurant", radius: 25000) do
      {:ok, places} ->
        IO.puts("✅ PlacesService returned #{length(places)} restaurants")
        if length(places) > 0 do
          first_place = hd(places)
          lat = Map.get(first_place, :latitude)
          lng = Map.get(first_place, :longitude)
          IO.puts("  First place: #{Map.get(first_place, :name)} at #{lat}, #{lng}")
        end
      {:error, reason} ->
        IO.puts("❌ PlacesService failed: #{reason}")
    end
    
    IO.puts("\n✅ Debug complete!")
  end
end