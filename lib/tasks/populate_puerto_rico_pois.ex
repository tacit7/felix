defmodule Mix.Tasks.PopulatePuertoRicoPois do
  @moduledoc """
  Mix task to populate the places table with enriched Puerto Rico POI data.
  
  ## Usage
  
      mix populate_puerto_rico_pois
  """
  
  use Mix.Task
  import Ecto.Query
  require Logger
  
  alias RouteWiseApi.Repo
  alias RouteWiseApi.Places.Place

  @shortdoc "Populate Puerto Rico POIs with enriched data"

  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("🏝️ Starting Puerto Rico POI enrichment...")

    # Puerto Rico POI data with enriched information
    pois_data = [
      %{
        name: "Mosquito Bay (Puerto Mosquito), Vieques",
        formatted_address: "Vieques, PR",
        latitude: 18.0979,
        longitude: -65.5043,
        categories: ["natural_feature", "tourist_attraction"],
        rating: 4.8,
        description: "World-class bioluminescent lagoon framed by mangroves. Guided night paddles reveal neon-blue trails with every stroke.",
        tips: [
          "Use DEET-free insect repellent; mangrove launch area is swarming with bugs",
          "Wear quick-dry clothes and bring a towel; no changing facilities at bay",
          "Book a guided night kayak tour in advance (only way to see the bay)",
          "Check moon phases – new moon nights offer the brightest bioluminescence",
          "Stay overnight on Vieques; last ferries leave before bio-bay tours end"
        ],
        best_time_to_visit: "New moon nights during dry season (Dec–Apr) for darkest, clearest waters",
        duration_suggested: "2 hours (night tour)",
        accessibility: "Rough road and kayak entry; not wheelchair accessible (tours use vans/boats)",
        entry_fee: "No public entry – guided tour ~$50–$60 per person is required"
      },
      %{
        name: "Flamenco Beach, Culebra",
        formatted_address: "Culebra, PR",
        latitude: 18.3117,
        longitude: -65.3200,
        categories: ["natural_feature", "tourist_attraction", "beach"],
        rating: 4.9,
        description: "Horseshoe bay of turquoise water and powdery sand. Snorkel near reefs and the iconic rusted tank.",
        tips: [
          "Reserve Ceiba–Culebra ferry tickets 1–2 weeks ahead (or arrive by 5 am for standby)",
          "Pack water, snacks, and snorkel gear; limited kiosks and no shops on site",
          "Arrive early to snag a picnic table or shaded spot before crowds",
          "Explore west end for snorkeling by old tank; vibrant fish around reef",
          "Bring cash for entry ($2) and parking or taxis; few ATMs on the island"
        ],
        best_time_to_visit: "Weekday mornings for fewer crowds; winter months may even bring flamingos",
        duration_suggested: "Full day",
        accessibility: "Flat sandy beach with nearby lot; paths are unpaved, making wheelchair access difficult",
        entry_fee: "Small entrance fee (~$2) plus ~$30 round-trip ferry & transport"
      },
      %{
        name: "Castillo San Felipe del Morro (El Morro)",
        formatted_address: "Old San Juan, PR 00901",
        latitude: 18.4707,
        longitude: -66.1247,
        categories: ["tourist_attraction", "museum", "historical_landmark"],
        rating: 4.7,
        description: "16th-century Spanish fortress guarding San Juan Bay. Sweeping lawns, ocean vistas, and layered ramparts to explore.",
        tips: [
          "Wear comfortable shoes – the fort's six levels involve steep ramps and uneven steps",
          "Visit at opening (9 am) to beat cruise ship tour crowds and midday heat",
          "Carry water and a hat; open courtyards get very hot (water fountains available for refills)",
          "Try flying a kite on the lawn outside – a popular local pastime on breezy afternoons",
          "Keep your entry receipt; one $10 ticket covers both El Morro and Castillo San Cristóbal"
        ],
        best_time_to_visit: "Early morning (when gates open) for cooler temps and crowd-free exploration",
        duration_suggested: "2–3 hours",
        accessibility: "Historic fort with steep ramps; main plaza accessible by ramp/elevator, lower levels via stairs only",
        entry_fee: "$10 per adult (covers entry to El Morro and San Cristóbal forts)"
      },
      %{
        name: "San Juan National Historic Site",
        formatted_address: "Old San Juan, PR 00901",
        latitude: 18.4695,
        longitude: -66.1195,
        categories: ["tourist_attraction", "museum", "historical_landmark"],
        rating: 4.7,
        description: "UNESCO district of walls, bastions, and twin forts. Cobblestones, colonial facades, and panoramic walks above the sea.",
        tips: [
          "Wear sturdy shoes – cobblestones and fortress ramps can be slippery and uneven",
          "Use one ticket for both El Morro & San Cristóbal; save your stub for the second fort",
          "Plan to arrive early if a cruise ship is in port, as sites get busy by late morning",
          "Carry water and sunscreen; there is minimal shade when walking the city walls",
          "Allow time to walk between forts (15–20 min); the free trolley service is currently suspended"
        ],
        best_time_to_visit: "Morning, before heat and tour groups, especially during peak Dec–Apr season",
        duration_suggested: "4–5 hours (half-day)",
        accessibility: "Steep ramps, stairs and narrow passages throughout; only key areas of forts have ramps/elevators",
        entry_fee: "$10 per person (good for all fortifications); children under 15 free"
      },
      %{
        name: "Laguna Grande (Bioluminescent Bay, Fajardo)",
        formatted_address: "Fajardo, PR",
        latitude: 18.3789,
        longitude: -65.6283,
        categories: ["natural_feature", "tourist_attraction"],
        rating: 4.5,
        description: "Mangrove channel leading to a glowing lagoon. Kayak under dark skies to watch plankton spark to life.",
        tips: [
          "Aim for a moonless night tour – darker skies mean a brighter bioluminescent glow",
          "Combine it with an El Yunque trip; many tours offer a rainforest visit plus bio-bay in one day",
          "Wear swimwear or quick-dry clothing; you'll get wet kayaking through mangrove channels (no changing rooms)",
          "If traveling with young kids or mobility issues, choose an electric boat tour instead of kayaks",
          "Bring a towel and bug spray (DEET-free); the launch area can be buggy, but chemicals harm the plankton"
        ],
        best_time_to_visit: "Around new moon (little moonlight) and during dry season for brightest waters",
        duration_suggested: "2 hours (evening tour)",
        accessibility: "Kayak launch through narrow mangrove tunnel – not wheelchair accessible; some operators offer boat options for limited mobility",
        entry_fee: "No public fee; guided kayak tour ~$50–$65 (boat tours ~$50 for ~75 min)"
      },
      %{
        name: "La Chiva (Blue Beach), Vieques",
        formatted_address: "Vieques, PR",
        latitude: 18.0959,
        longitude: -65.3939,
        categories: ["natural_feature", "beach"],
        rating: 4.8,
        description: "Long, wild strand inside the wildlife refuge. Clear, calm water and off-the-grid feel; bring your own shade.",
        tips: [
          "Bring everything you'll need – no facilities or food stands here, so pack water, snacks, and sunblock",
          "Rent a 4x4 vehicle; access is via bumpy dirt roads within the wildlife refuge",
          "Arrive early to claim one of the few shaded spots or bring an umbrella for sun breaks",
          "Fantastic snorkeling off this wide beach – pack snorkel gear to explore the clear waters and coral spots",
          "Beach is often breezy with a 'wild' feel; water is usually calm, but no lifeguards so swim with caution"
        ],
        best_time_to_visit: "Dry season (Nov–Apr) for sun and clear water; weekdays to have this secluded beach almost to yourself",
        duration_suggested: "Half day",
        accessibility: "Remote natural beach reached by dirt track; soft sand and lack of ramps make wheelchair access impractical",
        entry_fee: "Free (within Vieques National Wildlife Refuge)"
      },
      %{
        name: "El Yunque National Forest",
        formatted_address: "Puerto Rico",
        latitude: 18.3119,
        longitude: -65.7884,
        categories: ["park", "natural_feature", "tourist_attraction"],
        rating: 4.6,
        description: "Lush rainforest of waterfalls, ferns, and mountain views. Short dips and longer hikes deliver classic tropical scenery.",
        tips: [
          "Arrive by 7:30–8 am; entry is first-come, first-served for only 200 cars (no reservation needed now)",
          "Bring a lightweight rain jacket and dry clothes – brief showers are daily in the rainforest",
          "Wear shoes that can get muddy and wet (sport sandals or old sneakers with good grip)",
          "No restaurants inside – pack water, snacks, and lunch; nearby Luquillo kiosks are great after hiking",
          "Plan offline maps or download trail info; cell signal is poor once you're deep in the forest"
        ],
        best_time_to_visit: "Early morning (forest opens 7:30 am) for cooler temps and fewer people on trails",
        duration_suggested: "5–6 hours (half-day)",
        accessibility: "Mountainous terrain and slippery paths – most trails are not wheelchair-friendly (Angelito Trail is one of the few flat, accessible paths)",
        entry_fee: "Free entry to forest; El Portal Visitor Center optional $8 for adults"
      },
      %{
        name: "La Factoría (bar), Old San Juan",
        formatted_address: "148 Calle San Sebastián, San Juan, PR 00901",
        latitude: 18.4672,
        longitude: -66.1171,
        categories: ["bar", "night_club"],
        rating: 4.4,
        description: "Speakeasy-style cocktail labyrinth. Multiple rooms, solid classics, and late-night salsa without the pretension.",
        tips: [
          "Look for an unmarked door at Calle San Sebastián #148 – there's no sign, just follow the crowd inside",
          "Explore beyond the first bar – six hidden rooms with different music (including a salsa room) await in the back",
          "Live salsa band nights every Sunday and Monday at 10 pm in the Shing-A-Ling dance room",
          "Arrive before 10 pm on weekends; lines form late-night and it gets packed, making it hard to order cocktails",
          "Don't miss their signature Lavender Mule cocktail (vodka, ginger, lavender) – a house favorite"
        ],
        best_time_to_visit: "Late evening (after 9 pm) for a lively vibe; Sundays/Mondays if you want to catch the salsa night",
        duration_suggested: "2–3 hours (a full night out)",
        accessibility: "Street-level entrance and main bar are wheelchair accessible, but narrow doorways between crowded rooms may be challenging to navigate",
        entry_fee: "No cover charge; craft cocktails average $10–$15 each"
      },
      %{
        name: "Old San Juan",
        formatted_address: "Old San Juan, PR",
        latitude: 18.4658,
        longitude: -66.1057,
        categories: ["neighborhood", "tourist_attraction", "historical_landmark"],
        rating: 4.7,
        description: "Compact colonial capital with pastel streets, plazas, and sea walls. Best explored on foot between cafes and ramparts.",
        tips: [
          "Wear comfy shoes – you'll be walking on hilly cobblestone streets and steep sidewalks",
          "Visit early morning or after 4 pm to avoid the harsh midday heat and cruise ship crowds",
          "Carry water and sun protection; shade is limited when exploring forts and city walls",
          "Many museums close Mon–Tue; plan around those days or check hours in advance",
          "Wander the waterfront Paseo de la Princesa and Paseo del Morro for views, cats, and a breezy break from traffic"
        ],
        best_time_to_visit: "Weekday mornings or evenings to dodge peak heat and tour groups",
        duration_suggested: "1 day (6–8 hours)",
        accessibility: "Some narrow sidewalks and high curbs – parts of Old San Juan can be hard to roll through in a wheelchair, but major plazas and the forts have ramps or curb cuts",
        entry_fee: "Free to stroll (public city); individual sites like forts or museums may charge their own fees"
      },
      %{
        name: "Vieques (island & municipality)",
        formatted_address: "Vieques, PR",
        latitude: 18.1367,
        longitude: -65.4419,
        categories: ["administrative_area_level_2", "tourist_attraction"],
        rating: 4.6,
        description: "Laid-back sister island with wild beaches, roaming horses, and the planet's brightest bio bay. Slow days, starry nights.",
        tips: [
          "Book your Vieques lodging and rental Jeep well ahead – both sell out during high season due to limited supply",
          "Consider flying (25 min from SJU) instead of the ferry; the ferry from Ceiba is cheap but often delayed and chaotic",
          "Rent a car on Vieques (no mainland rentals allowed) and opt for 4WD to reach remote beaches on rough dirt roads",
          "Arrange taxi pickup in advance for when you arrive at the ferry dock or airport – vehicles can be scarce upon arrival",
          "Pack cash; many small eateries and tour guides on Vieques are cash-only and ATMs can be unreliable in town"
        ],
        best_time_to_visit: "Late winter–spring (Feb–Apr) for ideal weather and calmer seas; avoid peak hurricane months (Sep–Oct)",
        duration_suggested: "2–3 days (overnight essential for Bio Bay)",
        accessibility: "Rustic island infrastructure – limited sidewalks, bumpy roads, and undeveloped beaches make wheelchair travel challenging outside of Isabel II town center",
        entry_fee: "Free entry (ferry ~$2 each way, or flights ~$150 one-way from San Juan)"
      },
      %{
        name: "La Playuela (Playa Sucia), Cabo Rojo",
        formatted_address: "Cabo Rojo, PR",
        latitude: 17.9449,
        longitude: -67.2073,
        categories: ["natural_feature", "beach"],
        rating: 4.7,
        description: "Dramatic crescent beach beneath limestone cliffs near the lighthouse. Views and water color steal the show.",
        tips: [
          "Drive slowly on the long unpaved road to Playa Sucia – it's full of bumps, but worth every mile for the view",
          "No facilities at this beach; bring plenty of water, food, and an umbrella or pop-up tent for shade",
          "Climb up to Los Morrillos Lighthouse (10-min hike) for panoramic cliff views before or after your beach time",
          "Stay in shallow areas if you're not a strong swimmer – after waist-deep the currents can pull you out quickly (no lifeguards on duty)",
          "Visit on a weekday if possible – summer weekends get busy with local families, and parking near the trailhead fills up"
        ],
        best_time_to_visit: "Summer weekdays for calm water and fewer crowds; get there early to snag a shaded spot",
        duration_suggested: "4–5 hours (beach + lighthouse)",
        accessibility: "Requires driving a rugged dirt road and a short hike over uneven ground; not accessible to wheelchairs or strollers",
        entry_fee: "Free (public beach and nature reserve)"
      },
      %{
        name: "Guavate (Lechón corridor), Cayey",
        formatted_address: "Cayey, PR",
        latitude: 18.1136,
        longitude: -66.1641,
        categories: ["restaurant", "tourist_attraction"],
        rating: 4.5,
        description: "Mountainside strip of roast-pork joints and weekend music. Order crispy skin, classic sides, and eat family-style.",
        tips: [
          "Go on Saturday or Sunday for the full lechón experience – live music, dancing, and the festive crowd",
          "Arrive before noon to beat the massive lines and traffic; top lechoneras get very crowded by lunch time",
          "Order a 'combinación' platter to sample roast pork plus classic sides like arroz con gandules, yuca, and morcilla",
          "Bring friends and share – go in a group and try a variety of pork dishes and sides family-style",
          "Bring cash for roadside vendors and parking (some lots charge ~$5); many lechoneras operate on a cash-only basis"
        ],
        best_time_to_visit: "Weekend before noon – Saturdays and Sundays are lively but you'll avoid the worst of the afternoon rush",
        duration_suggested: "Half day (3–4 hours for lunch and music)",
        accessibility: "Casual open-air eateries with picnic tables; uneven pavement and crowds can pose challenges for wheelchairs, though some lechoneras have ground-level access",
        entry_fee: "Free entry; generous pork platter about $10–$15 per person"
      },
      %{
        name: "Paseo del Morro",
        formatted_address: "Old San Juan, PR",
        latitude: 18.4707,
        longitude: -66.1275,
        categories: ["tourist_attraction", "park"],
        rating: 4.6,
        description: "Flat waterfront path hugging Old San Juan's walls. Breezy views, cats on the rocks, easy sunset stroll.",
        tips: [
          "Access this scenic promenade via the San Juan Gate or from El Morro's side – it's a flat 1.5-mile trail hugging the waterfront",
          "Go early morning or near sunset – there is no shade and midday sun can be brutal (bring a hat and water)",
          "Keep an eye out for wildlife: you'll see cats lounging on the rocks and iguanas basking by the path",
          "The path dead-ends at the fort's rugged coastline; turn around before dark as it's not lit at night",
          "Stroll with sturdy shoes – though paved, the occasional uneven stones and puddles after rain mean flip-flops are less ideal"
        ],
        best_time_to_visit: "Sunrise or sunset for cooler temps and golden views of the bay and city walls",
        duration_suggested: "1 hour (out-and-back walk)",
        accessibility: "Wide, level gravel path along the bay – generally wheelchair accessible from the San Juan Gate side",
        entry_fee: "Free"
      },
      %{
        name: "Hotel El Convento",
        formatted_address: "100 Calle Cristo, San Juan, PR 00901",
        latitude: 18.4647,
        longitude: -66.1056,
        categories: ["lodging", "tourist_attraction"],
        rating: 4.3,
        description: "Elegant 17th-century convent turned boutique hotel. Cool courtyard, tile floors, and quiet respite off the plaza.",
        tips: [
          "Even if you're not staying here, pop in to admire this 17th-century former convent's architecture and lush courtyard",
          "Enjoy the daily complimentary wine & cheese hour if you are a guest – a lovely tradition on the terrace at sundown",
          "Dress in smart casual attire especially in the evenings; the hotel maintains an elegant atmosphere",
          "Parking in Old San Juan is tricky – consider a taxi or nearby parking garage, then walk to the hotel",
          "Rooms are boutique-style with colonial decor – even non-guests can visit the lobby and art gallery"
        ],
        best_time_to_visit: "Evening for dinner or a cocktail in the courtyard (often live acoustic music on weekends)",
        duration_suggested: "30–60 minutes (longer if dining)",
        accessibility: "Historic building retrofitted with elevators and ramps – common areas are wheelchair accessible",
        entry_fee: "Free to enter; room rates ~$300+ per night if staying"
      },
      %{
        name: "Cayo Icacos",
        formatted_address: "Near Fajardo, PR",
        latitude: 18.3833,
        longitude: -65.6000,
        categories: ["natural_feature", "tourist_attraction"],
        rating: 4.7,
        description: "Uninhabited cay of white sand and clear shallows. Boat-in picnics and easy snorkeling off the beach.",
        tips: [
          "Book a catamaran or water taxi in advance – Icacos is only reachable by boat, and tours fill up fast",
          "Mornings are best: seas are typically calmer and you'll have more of the island to yourself",
          "There are zero facilities on this uninhabited cay – bring reef-safe sunscreen, a hat, and beach essentials",
          "Snorkel the reef on the east side for colorful fish and coral; ask guides about current strength",
          "Keep the island pristine – carry out all your trash with tour crews"
        ],
        best_time_to_visit: "Weekday morning on an early boat (8–9 am departure) to avoid crowds and afternoon chop",
        duration_suggested: "4–5 hours (half-day tour)",
        accessibility: "Requires boarding a boat and sometimes transferring to a dinghy – not recommended for serious mobility limitations",
        entry_fee: "No entry fee; typical sail/snorkel tour is ~$80–$100 per person including gear and lunch"
      },
      %{
        name: "Punta Borinquen Light (Ruinas de Faro), Aguadilla",
        formatted_address: "Aguadilla, PR",
        latitude: 18.4924,
        longitude: -67.1558,
        categories: ["tourist_attraction", "historical_landmark"],
        rating: 4.3,
        description: "Photogenic lighthouse ruins on windswept cliffs. Rugged edges, surf below, and big-sky sunsets.",
        tips: [
          "Follow the narrow road through Punta Borinquen Golf Course to reach the ruins – drive until pavement ends",
          "Visit at sunrise or sunset for spectacular lighting on the cliffs and ruins (and cooler temps)",
          "The structure is unstable – heed the warning signs and refrain from climbing on the crumbling walls",
          "You'll likely be alone out there – it's secluded, so consider going with a friend and avoid going after dark",
          "After exploring the ruins, you can continue down the dirt track to see isolated beaches popular with surfers"
        ],
        best_time_to_visit: "Early morning or sunset for best photos and temperatures",
        duration_suggested: "30 minutes",
        accessibility: "Uneven ground and rubble; no paved access – not accessible for wheelchairs or strollers",
        entry_fee: "Free"
      },
      %{
        name: "Café Manolín",
        formatted_address: "251 Calle Fortaleza, San Juan, PR 00901",
        latitude: 18.4644,
        longitude: -66.1083,
        categories: ["restaurant", "establishment"],
        rating: 4.2,
        description: "Old-school lunch counter in Old San Juan. Hearty Puerto Rican staples, quick service, fair prices.",
        tips: [
          "Arrive early or at off-peak hours for lunch – this Old San Juan institution fills up by noon",
          "Try the daily specials or cualquier sandwich criollo (local-style sandwiches) – portions are generous",
          "The vibe is classic diner meets Creole luncheonette – expect friendly but speedy service",
          "Great place to sample Puerto Rican comfort food: ham croquettes, asopao, mofongo, and cafecito",
          "They close after lunch (not open for dinner most days), and aren't open on Sunday"
        ],
        best_time_to_visit: "Weekday before noon for brunch or an early lunch (no cruise ship crowds)",
        duration_suggested: "45–60 minutes (meal)",
        accessibility: "Located on street level with a small step at entrance; interior is narrow but navigable",
        entry_fee: "Free entry – meals average $10–$15"
      }
    ]

{inserted_count, updated_count, _errors} = 
      Enum.reduce(pois_data, {0, 0, []}, fn poi_data, {ins, upd, errs} ->
        case create_or_update_place(poi_data) do
          {:ok, :created} ->
            Logger.info("✅ Created: #{poi_data.name}")
            {ins + 1, upd, errs}
          
          {:ok, :updated} ->
            Logger.info("🔄 Updated: #{poi_data.name}")
            {ins, upd + 1, errs}
          
          {:error, reason} ->
            Logger.error("❌ Failed to create/update #{poi_data.name}: #{inspect(reason)}")
            {ins, upd, [poi_data.name | errs]}
        end
      end)

    Logger.info("🎉 Puerto Rico POI enrichment completed!")
    Logger.info("📊 Summary: #{inserted_count} created, #{updated_count} updated")
  end

  defp create_or_update_place(poi_data) do
    # Try to find existing place by name first
    existing_place = Repo.one(
      from p in Place,
      where: p.name == ^poi_data.name
    )

    case existing_place do
      nil ->
        # Create new place with all data
        place_attrs = %{
          name: poi_data.name,
          formatted_address: poi_data.formatted_address,
          latitude: Decimal.new(to_string(poi_data.latitude)),
          longitude: Decimal.new(to_string(poi_data.longitude)),
          categories: poi_data.categories,
          rating: poi_data.rating && Decimal.new(to_string(poi_data.rating)),
          description: poi_data.description,
          tips: poi_data.tips,
          best_time_to_visit: poi_data.best_time_to_visit,
          duration_suggested: poi_data.duration_suggested,
          accessibility: poi_data.accessibility,
          entry_fee: poi_data.entry_fee,
          cached_at: DateTime.utc_now(),
          popularity_score: 100,  # High score for curated POIs
          hidden_gem: false,
          overrated: false
        }

        %Place{}
        |> Place.manual_changeset(place_attrs)
        |> Repo.insert()
        |> case do
          {:ok, _place} -> {:ok, :created}
          {:error, changeset} -> {:error, changeset}
        end

      place ->
        # Update existing place with ONLY enriched fields
        enriched_attrs = %{
          tips: poi_data.tips,
          best_time_to_visit: poi_data.best_time_to_visit,
          duration_suggested: poi_data.duration_suggested,
          accessibility: poi_data.accessibility,
          entry_fee: poi_data.entry_fee
        }

        place
        |> Place.changeset(enriched_attrs)
        |> Repo.update()
        |> case do
          {:ok, _place} -> {:ok, :updated}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end
end