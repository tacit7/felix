defmodule RouteWiseApi.Repo.Migrations.PopulateSanJuanPois do
  use Ecto.Migration

  def up do
    # Insert San Juan POI data into places table
    # Using batch inserts for better performance
    
    execute """
    INSERT INTO places (
      google_place_id, 
      name, 
      formatted_address, 
      latitude, 
      longitude, 
      place_types, 
      rating, 
      reviews_count, 
      google_data, 
      cached_at, 
      inserted_at, 
      updated_at,
      description
    ) VALUES 
    -- Old San Juan
    ('san_juan_old_district', 'Old San Juan', 'Old San Juan, San Juan, PR', 18.46639, -66.11028, 
     ARRAY['neighborhood', 'historic_district', 'walking_area'], 4.8, 1250, '{}', NOW(), NOW(), NOW(),
     'Historic colonial district with blue cobblestones, pastel facades, and major sites like El Morro and San Cristóbal; prime base for strolling, shopping, and cafes.'),
    
    -- San Juan National Historic Site  
    ('san_juan_historic_site', 'San Juan National Historic Site', 'San Juan, PR', 18.4675, -66.11028,
     ARRAY['attraction', 'fortress', 'UNESCO_site', 'museum'], 4.9, 2100, '{}', NOW(), NOW(), NOW(),
     'NPS-managed complex of fortifications including Castillo San Felipe del Morro and Castillo San Cristóbal; epic coastal views, tunnels, and military history.'),
    
    -- Castillo San Felipe del Morro (El Morro)
    ('el_morro_fortress', 'Castillo San Felipe del Morro (El Morro)', 'El Morro, San Juan, PR', 18.4711, -66.1242,
     ARRAY['fortress', 'landmark', 'museum'], 4.9, 3200, '{}', NOW(), NOW(), NOW(),
     'Iconic 16th–18th century citadel guarding San Juan Bay; sprawling green lawn for kite-flying and sunsets, plus ramparts and ocean panoramas.'),
    
    -- Paseo del Morro
    ('paseo_del_morro', 'Paseo del Morro', 'Paseo del Morro, San Juan, PR', 18.46611, -66.12111,
     ARRAY['promenade', 'walking_area', 'viewpoint'], 4.7, 850, '{}', NOW(), NOW(), NOW(),
     'Seaside promenade at the base of El Morro''s walls; easy flat walk with sea spray, iguanas, and camera-ready angles of the fortifications.'),
    
    -- La Placita de Santurce
    ('la_placita_santurce', 'La Placita de Santurce', 'La Placita, Santurce, PR', 18.45058, -66.07062,
     ARRAY['market', 'nightlife', 'neighborhood'], 4.5, 1800, '{}', NOW(), NOW(), NOW(),
     'Daytime produce market that flips to nightlife hub after dark; bars, music, and restaurants radiate from the historic plaza.'),
    
    -- Condado (Santurce)
    ('condado_santurce', 'Condado (Santurce)', 'Condado, Santurce, PR', 18.45556, -66.07111,
     ARRAY['neighborhood', 'beach_area'], 4.4, 950, '{}', NOW(), NOW(), NOW(),
     'High-energy beachfront district with resorts, shopping, and dining along Ashford Avenue; good base for walkers and beach-seekers.'),
    
    -- Condado Vanderbilt Hotel
    ('condado_vanderbilt', 'Condado Vanderbilt Hotel', 'Ashford Avenue, Condado, PR', 18.458611, -66.075833,
     ARRAY['hotel', 'landmark'], 4.6, 1200, '{}', NOW(), NOW(), NOW(),
     '1919 grande dame hotel on Ashford Avenue; restored classic with oceanfront terraces and upscale dining.'),
    
    -- Hotel El Convento
    ('hotel_el_convento', 'Hotel El Convento', 'Old San Juan, PR', 18.459664, -66.118944,
     ARRAY['hotel', 'historic_building'], 4.7, 800, '{}', NOW(), NOW(), NOW(),
     'Former 17th‑century Carmelite convent turned boutique hotel by the cathedral; cloistered courtyards and Old San Juan views.'),
    
    -- Isla Verde
    ('isla_verde', 'Isla Verde', 'Isla Verde, PR', 18.437, -66.006,
     ARRAY['neighborhood', 'beach_area'], 4.3, 1100, '{}', NOW(), NOW(), NOW(),
     'Resort and residential strip east of Condado with a broad sandy beach and quick airport access.'),
    
    -- Piñones State Forest
    ('pinones_forest', 'Piñones State Forest', 'Piñones, PR', 18.443835, -65.966277,
     ARRAY['state_forest', 'boardwalk', 'beach_area'], 4.6, 750, '{}', NOW(), NOW(), NOW(),
     'Mangrove coast with bike path, rustic kiosks, and local fritura stands; excellent for a food-and-beach loop outside San Juan.');
    """

    # Insert places without coordinates (these would need geocoding)
    execute """
    INSERT INTO places (
      google_place_id, 
      name, 
      formatted_address, 
      latitude, 
      longitude, 
      place_types, 
      rating, 
      reviews_count, 
      google_data, 
      cached_at, 
      inserted_at, 
      updated_at,
      description
    ) VALUES 
    -- Condado Beach (missing coordinates)
    ('condado_beach', 'Condado Beach', 'Condado Beach, San Juan, PR', NULL, NULL,
     ARRAY['beach'], 4.3, 890, '{}', NOW(), NOW(), NOW(),
     'Long urban beach fronting the Condado hotels; strong currents beyond the shallows, but classic city-beach vibe.'),
    
    -- Playita del Condado (missing coordinates)  
    ('playita_condado', 'Playita del Condado', 'Condado, San Juan, PR', NULL, NULL,
     ARRAY['beach', 'family_friendly'], 4.5, 320, '{}', NOW(), NOW(), NOW(),
     'Small protected beach at the western end of Condado with calmer waters; handy for quick swims and sunsets near the lagoon.'),
    
    -- La Concha Resort (missing coordinates)
    ('la_concha_resort', 'La Concha Resort', 'Condado, San Juan, PR', NULL, NULL,
     ARRAY['hotel', 'landmark'], 4.2, 1500, '{}', NOW(), NOW(), NOW(),
     'Midcentury-modern resort with the famous conch-shell lobby; nightlife energy and direct beach access in Condado.'),
    
    -- La Factoría (missing coordinates)
    ('la_factoria_bar', 'La Factoría (bar)', 'Old San Juan, PR', NULL, NULL,
     ARRAY['bar', 'nightlife'], 4.8, 2800, '{}', NOW(), NOW(), NOW(),
     'Award‑winning cocktail labyrinth in Old San Juan with multiple rooms and live salsa nights; staple on The World''s 50 Best Bars lists.'),
    
    -- Café Manolín (missing coordinates)
    ('cafe_manolin', 'Café Manolín', 'Old San Juan, PR', NULL, NULL,
     ARRAY['restaurant'], 4.4, 650, '{}', NOW(), NOW(), NOW(),
     'Old‑school diner for Puerto Rican comfort plates like mofongo and bistec; reliable, fast, and centrally placed in Old San Juan.');
    """

    # Insert more regional places with coordinates
    execute """
    INSERT INTO places (
      google_place_id, 
      name, 
      formatted_address, 
      latitude, 
      longitude, 
      place_types, 
      rating, 
      reviews_count, 
      google_data, 
      cached_at, 
      inserted_at, 
      updated_at,
      description
    ) VALUES 
    -- Laguna Grande Bioluminescent Bay
    ('laguna_grande_bio', 'Laguna Grande (Bioluminescent Bay, Fajardo)', 'Fajardo, PR', 18.383333, -65.616667,
     ARRAY['lagoon', 'bioluminescent_bay', 'kayaking'], 4.9, 1800, '{}', NOW(), NOW(), NOW(),
     'Year‑round bioluminescent lagoon in the Cabezas de San Juan reserve; night kayak tours through mangroves to glowing waters.'),
    
    -- Cayo Icacos
    ('cayo_icacos', 'Cayo Icacos', 'Fajardo, PR', 18.38639, -65.58889,
     ARRAY['islet', 'snorkeling', 'beach'], 4.7, 450, '{}', NOW(), NOW(), NOW(),
     'Uninhabited islet off Fajardo with clear water and reefs; popular boat/snorkel day trip.'),
    
    -- El Yunque National Forest
    ('el_yunque_forest', 'El Yunque National Forest', 'El Yunque, PR', 18.31056, -65.79139,
     ARRAY['national_forest', 'hiking', 'waterfalls'], 4.8, 5200, '{}', NOW(), NOW(), NOW(),
     'Only tropical rainforest in the U.S. National Forest System; trails to towers and cascades with frequent afternoon showers.'),
    
    -- Yokahú Tower
    ('yokahu_tower', 'Yokahú Tower (El Yunque)', 'El Yunque, PR', 18.312512, -65.770238,
     ARRAY['viewpoint', 'tower'], 4.6, 1100, '{}', NOW(), NOW(), NOW(),
     '1963 observation tower with sweeping Luquillo range and coast views; short climb from the parking area.'),
    
    -- Mosquito Bay, Vieques
    ('mosquito_bay_vieques', 'Mosquito Bay (Puerto Mosquito), Vieques', 'Vieques, PR', 18.10194, -65.44583,
     ARRAY['bioluminescent_bay', 'kayaking', 'nature_reserve'], 5.0, 3200, '{}', NOW(), NOW(), NOW(),
     'Brightest bioluminescent bay in the world under ideal conditions; guided night paddles only.'),
    
    -- La Chiva Blue Beach
    ('la_chiva_beach', 'La Chiva (Blue Beach), Vieques', 'Vieques, PR', 18.1125, -65.386389,
     ARRAY['beach', 'snorkeling'], 4.9, 890, '{}', NOW(), NOW(), NOW(),
     'Long crescent of pale sand with calm waters and reefy pockets; signature south‑coast beach on Vieques.'),
    
    -- Flamenco Beach
    ('flamenco_beach', 'Flamenco Beach, Culebra', 'Culebra, PR', 18.329278, -65.317917,
     ARRAY['beach', 'snorkeling'], 4.9, 4200, '{}', NOW(), NOW(), NOW(),
     'Turquoise, shelved bay repeatedly ranked among the world''s best; amenities and camping near the sand.');
    """

    # Insert western Puerto Rico places
    execute """
    INSERT INTO places (
      google_place_id, 
      name, 
      formatted_address, 
      latitude, 
      longitude, 
      place_types, 
      rating, 
      reviews_count, 
      google_data, 
      cached_at, 
      inserted_at, 
      updated_at,
      description
    ) VALUES 
    -- Domes Beach
    ('domes_beach_rincon', 'Domes Beach (Playa Domes), Rincón', 'Rincón, PR', 18.364722, -67.270278,
     ARRAY['beach', 'surf'], 4.6, 780, '{}', NOW(), NOW(), NOW(),
     'Powerful winter surf near the decommissioned BONUS reactor and Punta Higuero Lighthouse; strong currents, experienced swimmers only.'),
    
    -- Maria''s Beach
    ('marias_beach_rincon', 'Maria''s Beach, Rincón', 'Rincón, PR', 18.3576, -67.2688,
     ARRAY['beach', 'surf'], 4.5, 650, '{}', NOW(), NOW(), NOW(),
     'Classic Rincón break with consistent sets; beach bars and whale watching in season.'),
    
    -- Punta Borinquen Light
    ('punta_borinquen_light', 'Punta Borinquen Light (Aguadilla)', 'Aguadilla, PR', 18.48869, -67.16163,
     ARRAY['lighthouse', 'viewpoint', 'historic_site'], 4.7, 420, '{}', NOW(), NOW(), NOW(),
     'Historic lighthouse set on cliffs above Aguadilla and the former Ramey Air Force Base; dramatic coastal vistas.'),
    
    -- La Playuela (Playa Sucia)
    ('la_playuela_cabo_rojo', 'La Playuela (Playa Sucia), Cabo Rojo', 'Cabo Rojo, PR', 17.932778, -67.187778,
     ARRAY['beach', 'scenic_view'], 4.8, 950, '{}', NOW(), NOW(), NOW(),
     'Horseshoe cove below Los Morrillos lighthouse with bright water and karst cliffs; photogenic, no services.'),
    
    -- Mar Chiquita
    ('mar_chiquita_manati', 'Mar Chiquita (Manatí)', 'Manatí, PR', 18.47383, -66.48517,
     ARRAY['beach', 'swimming', 'photography'], 4.7, 380, '{}', NOW(), NOW(), NOW(),
     'Pocket beach in a round cove protected by limestone rock walls; calm on low swell, dramatic in winter surf.'),
    
    -- Cueva del Indio
    ('cueva_del_indio', 'Cueva del Indio (Arecibo)', 'Arecibo, PR', 18.492739, -66.64155,
     ARRAY['nature_reserve', 'cave', 'viewpoint'], 4.6, 520, '{}', NOW(), NOW(), NOW(),
     'Sea cave and cliff arches with Taíno petroglyphs and blowholes; spectacular coastal geology.'),
    
    -- Cayey
    ('cayey_town', 'Cayey (municipality)', 'Cayey, PR', 18.11167, -66.16583,
     ARRAY['town', 'mountain_town'], 4.2, 280, '{}', NOW(), NOW(), NOW(),
     'Cooler mountain town that anchors the Guavate lechón route and access to Carite forest and reservoirs.'),
    
    -- Casa Bacardí
    ('casa_bacardi', 'Casa Bacardí (Cathedral of Rum), Cataño', 'Cataño, PR', 18.46054, -66.14227,
     ARRAY['distillery', 'tour'], 4.5, 2800, '{}', NOW(), NOW(), NOW(),
     'Visitor center and historic distillery complex of Bacardí across the bay from Old San Juan; cocktail classes and tastings.');
    """

    # Insert places without coordinates that need geocoding
    execute """
    INSERT INTO places (
      google_place_id, 
      name, 
      formatted_address, 
      latitude, 
      longitude, 
      place_types, 
      rating, 
      reviews_count, 
      google_data, 
      cached_at, 
      inserted_at, 
      updated_at,
      description
    ) VALUES 
    -- Vieques (general island)
    ('vieques_island', 'Vieques (island & municipality)', 'Vieques, PR', NULL, NULL,
     ARRAY['island', 'beaches', 'snorkeling'], 4.8, 1200, '{}', NOW(), NOW(), NOW(),
     'Low-key island east of Puerto Rico with wild beaches, horses, and world-class bioluminescence at Mosquito Bay.'),
    
    -- Rincón (general municipality)  
    ('rincon_municipality', 'Rincón (municipality)', 'Rincón, PR', NULL, NULL,
     ARRAY['town', 'surf_area'], 4.6, 890, '{}', NOW(), NOW(), NOW(),
     'Surf capital on the island''s far west with sunset points and a string of named breaks from Domes to Tres Palmas.'),
    
    -- Guavate food route
    ('guavate_lechon', 'Guavate (lechón corridor), Cayey', 'Guavate, Cayey, PR', NULL, NULL,
     ARRAY['food_route', 'neighborhood'], 4.7, 1500, '{}', NOW(), NOW(), NOW(),
     'Mountain roadside strip famous for spit‑roasted pork (lechón) and live music, especially on weekends.');
    """

    # Log success
    execute "SELECT 'San Juan POI data inserted successfully' AS status;"
  end

  def down do
    # Remove all inserted POI data
    execute """
    DELETE FROM places WHERE google_place_id IN (
      'san_juan_old_district', 'san_juan_historic_site', 'el_morro_fortress', 
      'paseo_del_morro', 'la_placita_santurce', 'condado_santurce', 
      'condado_beach', 'playita_condado', 'condado_vanderbilt', 'la_concha_resort',
      'hotel_el_convento', 'la_factoria_bar', 'cafe_manolin', 'isla_verde',
      'pinones_forest', 'laguna_grande_bio', 'cayo_icacos', 'el_yunque_forest',
      'yokahu_tower', 'mosquito_bay_vieques', 'la_chiva_beach', 'flamenco_beach',
      'domes_beach_rincon', 'marias_beach_rincon', 'punta_borinquen_light',
      'la_playuela_cabo_rojo', 'mar_chiquita_manati', 'cueva_del_indio',
      'vieques_island', 'rincon_municipality', 'guavate_lechon', 'cayey_town',
      'casa_bacardi'
    );
    """
  end
end