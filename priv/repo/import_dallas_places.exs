# Import Dallas places data from CSV
import Ecto.Query
alias RouteWiseApi.{Repo, Places.Place}

# Read CSV data
csv_data = """
name,latitude,longitude,place_types,description,wiki_image
"The Sixth Floor Museum at Dealey Plaza",32.779167,-96.808889,"museum,historical_site","Museum chronicling JFK's life, presidency, and assassination, located on the sixth and seventh floors of the former Texas School Book Depository building. Features exhibits detailing the history of the 1960s and the impact of JFK's legacy.","https://en.wikipedia.org/wiki/File:Sixth_Floor_Museum_at_Dealey_Plaza.jpg"
"Dealey Plaza",32.778889,-96.808056,"historical_site,landmark","Historic birthplace of Dallas and site of President Kennedy's assassination. A National Historic Landmark that serves as a memorial to this pivotal moment in American history.","https://en.wikipedia.org/wiki/File:Dealey_Plaza_2003.jpg"
"Kennedy Memorial",32.776389,-96.806944,"memorial,landmark","Memorial to President John F. Kennedy located near Dealey Plaza. A simple yet powerful tribute designed by architect Philip Johnson, featuring a square concrete structure.","https://en.wikipedia.org/wiki/File:JFK_Memorial_Dallas.jpg"
"Pioneer Plaza",32.776111,-96.807222,"park,sculpture,landmark","Features the world's largest bronze sculpture of a cattle drive with 49 bronze steers and three cowboys. This impressive installation commemorates Dallas's cattle-driving heritage.","https://en.wikipedia.org/wiki/File:Pioneer_Plaza_Dallas.jpg"
"Dallas Museum of Art",32.787778,-96.801111,"museum,art_gallery,culture","Houses a collection spanning artistic eras and continents with free admission to permanent collections. Features contemporary and classical works, ancient artifacts, and rotating exhibitions.","https://en.wikipedia.org/wiki/File:Dallas_Museum_of_Art_building.jpg"
"Perot Museum of Nature and Science",32.786944,-96.806667,"museum,family_attraction,education","Top family attraction featuring interactive exhibits that engage children and adults in learning about natural history, space, technology, and science.","https://en.wikipedia.org/wiki/File:Perot_Museum_of_Nature_and_Science.jpg"
"Nasher Sculpture Center",32.788333,-96.801389,"museum,art_gallery,sculpture","Premier modern and contemporary sculpture collection housed in a stunning building designed by Renzo Piano. Features both indoor galleries and a beautiful outdoor sculpture garden.","https://en.wikipedia.org/wiki/File:Nasher_Sculpture_Center.jpg"
"Dallas Arboretum & Botanical Gardens",32.822222,-96.717778,"garden,park,attraction","66-acre botanical garden featuring stunning seasonal displays, especially famous for spring blooms during Dallas Blooms festival. Offers beautiful landscaped gardens with scenic White Rock Lake views.","https://en.wikipedia.org/wiki/File:Dallas_Arboretum_and_Botanical_Garden.jpg"
"Klyde Warren Park",32.789167,-96.801944,"park,food_trucks,events","Unique 5.2-acre park built over the Woodall Rodgers Freeway, connecting downtown and uptown Dallas. Features food trucks, free Wi-Fi, dog park, children's area, and performance pavilion.","https://en.wikipedia.org/wiki/File:Klyde_Warren_Park.jpg"
"Reunion Tower",32.775278,-96.808889,"observation_tower,landmark,attraction","Iconic 470-foot observation tower offering 360-degree panoramic views of Dallas from its GeO-Deck. Known locally as 'The Ball' due to its distinctive spherical shape.","https://en.wikipedia.org/wiki/File:Reunion_Tower_Dallas.JPG"
"Deep Ellum",32.784722,-96.783333,"neighborhood,nightlife,music,art","Historic entertainment district east of downtown known for its vibrant nightlife, live music venues, street art, and eclectic mix of bars, restaurants, and shops.","https://en.wikipedia.org/wiki/File:Deep_Ellum_Dallas_street_art.jpg"
"Bishop Arts District",32.734722,-96.825833,"neighborhood,shopping,dining,art","Walkable Oak Cliff district featuring independent shops, local restaurants, street art, and performing arts venues. Known for its community feel and the historic Kessler Theater.","https://en.wikipedia.org/wiki/File:Bishop_Arts_District_Dallas.jpg"
"AT&T Stadium",32.747500,-97.092778,"stadium,sports,entertainment","Home of the Dallas Cowboys, this architectural marvel features the world's largest high-definition video screen and retractable roof. Offers tours and hosts major events.","https://en.wikipedia.org/wiki/File:Cowboys_Stadium_full_view.jpg"
"Dallas World Aquarium",32.783056,-96.805278,"aquarium,family_attraction,zoo","Immersive experience combining aquatic exhibits with rainforest environments. Features a walk-through rainforest tunnel and diverse marine life in naturalistic habitats.","https://en.wikipedia.org/wiki/File:Dallas_World_Aquarium.jpg"
"White Rock Lake Park",32.823333,-96.716667,"park,lake,recreation","1,015-acre lake located 5 miles northeast of downtown Dallas, popular for walking, jogging, cycling, and kayaking. Offers scenic trails and wildlife viewing.","https://en.wikipedia.org/wiki/File:White_Rock_Lake_Dallas.jpg"
"Dallas Zoo",32.740833,-96.815278,"zoo,family_attraction,wildlife","Texas's largest zoo spanning 106 acres, home to over 2,000 animals representing 406 species. Features immersive habitats and the award-winning Giants of the Savanna exhibit.","https://en.wikipedia.org/wiki/File:Dallas_Zoo_entrance.jpg"
"Uptown District",32.798056,-96.801944,"neighborhood,dining,nightlife,shopping","Trendy urban district popular with young professionals, featuring upscale restaurants, bars, boutiques, and high-rise living. Connected to downtown via the free McKinney Avenue Trolley.","https://en.wikipedia.org/wiki/File:Dallas_Uptown_district.jpg"
"Katy Trail",32.801667,-96.803889,"trail,recreation,park","3.5-mile urban trail following the path of the old Missouri-Kansas-Texas Railroad. Popular with cyclists, runners, and walkers, connecting several Dallas neighborhoods.","https://en.wikipedia.org/wiki/File:Katy_Trail_Dallas.jpg"
"Fair Park",32.767500,-96.758889,"park,historical_site,fairgrounds","277-acre National Historic Landmark featuring Art Deco architecture from the 1936 Texas Centennial Exposition. Home to the annual State Fair of Texas and multiple museums.","https://en.wikipedia.org/wiki/File:Fair_Park_Dallas.jpg"
"McKinney Avenue",32.798333,-96.802222,"street,transportation,historic","Historic street running through Uptown Dallas, served by the free McKinney Avenue Trolley - Dallas's last remaining streetcar line. Features shopping and dining.","https://en.wikipedia.org/wiki/File:McKinney_Avenue_Trolley_Dallas.jpg"
"Nuri Steakhouse",32.798611,-96.802500,"restaurant,steakhouse,fine_dining","Asian-influenced steakhouse opened in late 2024, collaboration between chef Mario Hernandez and Michelin-recognized chef Minji Kim. Features premium Texas Akaushi beef.",""
"Tatsu",32.787500,-96.800833,"restaurant,sushi,fine_dining","Michelin-starred restaurant offering Edomae-style omakase experience. Features approximately 15 courses with exceptional nigiri and authentic Japanese technique.",""
"Catch Dallas",32.798889,-96.802778,"restaurant,seafood,upscale_dining","Eighth location of the NYC-based Catch Hospitality Group located in Uptown. Known for Truffle Sashimi and tableside hot-rock Japanese Wagyu.",""
"Georgie",32.787222,-96.801667,"restaurant,fine_dining,american","Michelin-recognized restaurant featuring seasonal menus that blend Texas influences with global flavors. Known for technically precise cooking and interesting flavor combinations.",""
"Fort Worth Stockyards",32.789444,-97.343889,"historical_site,entertainment,tourist_attraction","National Historic District featuring the world's only twice-daily cattle drive and Billy Bob's Texas. Offers authentic cowboy culture, shopping, dining, and entertainment.","https://en.wikipedia.org/wiki/File:Fort_Worth_Stockyards.jpg"
"Fort Worth Cultural District",32.757778,-97.361111,"cultural_district,museum,arts","Home to world-class museums including the Kimbell Art Museum, Modern Art Museum of Fort Worth, and Amon Carter Museum with finest art collections in the United States.","https://en.wikipedia.org/wiki/File:Fort_Worth_Cultural_District.jpg"
"Dr Pepper Museum",31.549167,-97.134722,"museum,historical_site,attraction","Located in Waco, this museum celebrates the birthplace of Dr Pepper soft drink. Features exhibits on the history and cultural impact of Dr Pepper on American society.","https://en.wikipedia.org/wiki/File:Dr_Pepper_Museum_Waco.jpg"
"American Airlines Center",32.790556,-96.810278,"arena,sports,entertainment","Multi-purpose arena serving as home to the Dallas Mavericks and Dallas Stars. Hosts major concerts, sporting events, and entertainment shows in downtown Dallas.","https://en.wikipedia.org/wiki/File:American_Airlines_Center_Dallas.jpg"
"Holocaust Museum Dallas",32.783611,-96.803889,"museum,historical_site,education","Moving museum dedicated to Holocaust education and remembrance. Features artifacts, testimonials, and educational exhibits that promote tolerance and understanding.","https://en.wikipedia.org/wiki/File:Dallas_Holocaust_Museum.jpg"
"George W. Bush Presidential Library & Museum",32.841111,-96.777778,"museum,library,historical_site","Presidential library and museum dedicated to the 43rd President. Features exhibits on Bush's presidency, September 11th, the Iraq War, and a full replica of the Oval Office.","https://en.wikipedia.org/wiki/File:George_W_Bush_Presidential_Library.jpg"
"""

# Parse CSV data (simple parsing since we control the format)
lines = String.split(csv_data, "\n", trim: true)
[_header | data_lines] = lines

# Function to parse CSV line (handles quoted fields)
parse_csv_line = fn line ->
  # Simple CSV parsing for our controlled data
  fields = 
    line
    |> String.replace(~r/^"/, "")
    |> String.replace(~r/"$/, "")
    |> String.split(~r/","|,(?=")/)
    |> Enum.map(&String.replace(&1, ~r/^"|"$/, ""))
  
  case fields do
    [name, lat, lng, types, desc, wiki] ->
      {name, lat, lng, types, desc, wiki}
    _ ->
      IO.puts("Warning: Could not parse line: #{line}")
      nil
  end
end

# Function to convert parsed data to place attributes
to_place_attrs = fn {name, lat, lng, types, desc, wiki} ->
  place_types = String.split(types, ",") |> Enum.map(&String.trim/1)
  
  %{
    name: name,
    latitude: Decimal.new(lat),
    longitude: Decimal.new(lng),
    place_types: place_types,
    description: desc,
    wiki_image: if(wiki == "", do: nil, else: wiki),
    cached_at: DateTime.utc_now(),
    formatted_address: "Dallas, TX, USA"  # Default address for Dallas places
  }
end

IO.puts("🚀 Starting Dallas places import...")

# Parse and import data
{places_imported, places_skipped} = 
  Enum.reduce(data_lines, {0, 0}, fn line, {imported, skipped} ->
    case parse_csv_line.(line) do
      nil -> 
        {imported, skipped + 1}
      
      parsed_data ->
        place_attrs = to_place_attrs.(parsed_data)
        
        # Check if place already exists by name
        existing_place = Repo.get_by(Place, name: place_attrs.name)
        
        if existing_place do
          IO.puts("⏭️  Skipping existing place: #{place_attrs.name}")
          {imported, skipped + 1}
        else
          case Repo.insert(Place.changeset(%Place{}, place_attrs)) do
            {:ok, place} ->
              IO.puts("✅ Imported: #{place.name}")
              {imported + 1, skipped}
              
            {:error, changeset} ->
              IO.puts("❌ Failed to import #{place_attrs.name}: #{inspect(changeset.errors)}")
              {imported, skipped + 1}
          end
        end
    end
  end)

IO.puts("\n🎉 Import completed!")
IO.puts("✅ Places imported: #{places_imported}")
IO.puts("⏭️  Places skipped: #{places_skipped}")
IO.puts("📊 Total places in database: #{Repo.aggregate(Place, :count, :id)}")