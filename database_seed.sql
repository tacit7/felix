-- RouteWise Database Seed Script
-- Generated from suggested trips data for Phoenix backend

-- Create tables first
CREATE TABLE IF NOT EXISTS suggested_trips (
  id VARCHAR PRIMARY KEY,
  slug VARCHAR UNIQUE NOT NULL,
  title VARCHAR NOT NULL,
  summary TEXT,
  description TEXT,
  duration VARCHAR,
  difficulty VARCHAR CHECK (difficulty IN ('Easy', 'Moderate', 'Challenging')),
  best_time VARCHAR,
  estimated_cost VARCHAR,
  hero_image VARCHAR,
  tips JSONB,
  tags JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trip_places (
  id VARCHAR PRIMARY KEY,
  trip_id VARCHAR REFERENCES suggested_trips(id),
  name VARCHAR NOT NULL,
  description TEXT,
  image VARCHAR,
  lat DECIMAL(10, 8),
  lng DECIMAL(11, 8),
  activities JSONB,
  best_time_to_visit VARCHAR,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trip_itinerary (
  id SERIAL PRIMARY KEY,
  trip_id VARCHAR REFERENCES suggested_trips(id),
  day INTEGER NOT NULL,
  title VARCHAR NOT NULL,
  location VARCHAR,
  activities JSONB,
  highlights JSONB,
  estimated_time VARCHAR,
  driving_time VARCHAR,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Insert suggested trips
INSERT INTO suggested_trips (id, slug, title, summary, description, duration, difficulty, best_time, estimated_cost, hero_image, tips, tags) VALUES
('pch-001', 'pacific-coast-highway', 'Pacific Coast Highway Adventure', 
'Experience the breathtaking beauty of California''s iconic coastline with stunning ocean views, charming coastal towns, and unforgettable sunsets.',
'The Pacific Coast Highway is one of America''s most scenic drives, stretching along California''s rugged coastline from San Francisco to San Diego. This 7-day journey takes you through some of the most beautiful and iconic locations on the West Coast.',
'7 Days', 'Easy', 'April - October', '$1,500 - $2,500',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'["Book Hearst Castle tours in advance", "Check road conditions for Big Sur (sometimes closed)", "Pack layers - coastal weather can be unpredictable", "Make dinner reservations at popular restaurants", "Fill up gas tank regularly - limited stations in Big Sur"]',
'["Coastal Drive", "Scenic", "Photography", "Nature", "Easy Driving"]'),

('gl-001', 'great-lakes', 'Great Lakes Circle Tour',
'Discover the majesty of America''s inland seas with stunning lakeshores, charming coastal towns, and diverse ecosystems across multiple states.',
'The Great Lakes Circle Tour takes you around the world''s largest group of freshwater lakes, offering spectacular scenery, rich maritime history, and diverse cultural experiences across the northern United States.',
'10 Days', 'Moderate', 'May - September', '$2,000 - $3,500',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=1200&h=600&fit=crop',
'["Pack warm clothes even in summer", "Book island ferries in advance", "Check lighthouse tour schedules", "Prepare for variable lake weather", "Consider camping reservations early"]',
'["Lakes", "Islands", "Lighthouses", "Nature", "History"]'),

('sf-001', 'san-francisco', 'San Francisco City Explorer',
'Immerse yourself in the vibrant culture, iconic landmarks, and diverse neighborhoods of the City by the Bay.',
'San Francisco offers an incredible urban adventure with its famous hills, historic cable cars, world-class dining, and eclectic neighborhoods each with their own unique character.',
'5 Days', 'Easy', 'September - November', '$1,200 - $2,000',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'["Layer clothing - weather changes quickly", "Book Alcatraz tickets well in advance", "Use public transportation - parking is difficult", "Try local sourdough bread and Dungeness crab", "Walk carefully on steep hills"]',
'["Urban", "Culture", "Food", "History", "Architecture"]'),

('ys-001', 'yellowstone', 'Yellowstone National Park',
'Explore America''s first national park with geysers, hot springs, wildlife, and pristine wilderness across Wyoming, Montana, and Idaho.',
'Yellowstone National Park is a wonderland of geothermal features, diverse wildlife, and stunning landscapes. Home to Old Faithful and thousands of other geothermal features, it''s a true natural treasure.',
'6 Days', 'Moderate', 'May - September', '$1,000 - $1,800',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'["Book accommodations a year in advance", "Bring bear spray for hiking", "Check road closures before visiting", "Pack layers for temperature changes", "Maintain safe distance from wildlife"]',
'["National Park", "Geysers", "Wildlife", "Hiking", "Photography"]'),

('gc-001', 'grand-canyon', 'Grand Canyon National Park',
'Marvel at one of the world''s most spectacular natural wonders with breathtaking views, hiking trails, and geological history.',
'The Grand Canyon is a UNESCO World Heritage Site and one of the most visited national parks in America. Its immense size and colorful landscape offers visitors multiple ways to experience this natural wonder.',
'4 Days', 'Moderate', 'April - May, September - November', '$800 - $1,400',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'["Start hiking early to avoid heat", "Bring plenty of water and snacks", "Wear layers - temperature varies by elevation", "Book helicopter tours in advance", "Respect wildlife and stay on trails"]',
'["National Park", "Hiking", "Photography", "Geology", "Adventure"]');

-- Insert trip places for Pacific Coast Highway
INSERT INTO trip_places (id, trip_id, name, description, image, lat, lng, activities, best_time_to_visit) VALUES
('pch-sf', 'pch-001', 'San Francisco',
'Start your journey in the iconic City by the Bay with its famous Golden Gate Bridge, steep hills, and vibrant culture.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
37.7749, -122.4194,
'["Golden Gate Bridge", "Fisherman''s Wharf", "Lombard Street", "Alcatraz Island"]',
'Morning departure'),

('pch-monterey', 'pch-001', 'Monterey Bay',
'World-famous aquarium and scenic 17-Mile Drive through Pebble Beach with stunning coastal views.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
36.6002, -121.8947,
'["Monterey Bay Aquarium", "17-Mile Drive", "Carmel-by-the-Sea", "Cannery Row"]',
'Full day'),

('pch-bigsur', 'pch-001', 'Big Sur',
'Dramatic cliffs meet crashing waves in this pristine wilderness area with towering redwoods and scenic hiking trails.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
36.2704, -121.8081,
'["McWay Falls", "Bixby Creek Bridge", "Julia Pfeiffer Burns State Park", "Nepenthe Restaurant"]',
'Sunrise to sunset'),

('pch-hearst', 'pch-001', 'Hearst Castle',
'Opulent mansion built by newspaper magnate William Randolph Hearst, featuring stunning architecture and art collections.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
35.6850, -121.1681,
'["Castle tours", "Gardens exploration", "Zebra viewing", "Historic exhibits"]',
'Half day'),

('pch-morrow', 'pch-001', 'Morro Bay',
'Charming harbor town dominated by the iconic 576-foot tall Morro Rock, perfect for kayaking and seafood.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
35.3659, -120.8507,
'["Morro Rock", "Kayaking", "Harbor walks", "Fresh seafood dining"]',
'Afternoon and sunset');

-- Insert trip places for Great Lakes Circle Tour
INSERT INTO trip_places (id, trip_id, name, description, image, lat, lng, activities, best_time_to_visit) VALUES
('gl-mackinac', 'gl-001', 'Mackinac Island',
'Historic island where cars are banned and horse-drawn carriages transport visitors through time.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
45.8492, -84.6189,
'["Grand Hotel visit", "Horse-drawn carriage tours", "Fort Mackinac", "Fudge shopping"]',
'Full day'),

('gl-pictured', 'gl-001', 'Pictured Rocks',
'Stunning multicolored cliffs rising from Lake Superior with waterfalls and pristine beaches.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
46.4619, -86.4614,
'["Boat tours", "Hiking trails", "Munising Falls", "Kayaking"]',
'Full day'),

('gl-apostle', 'gl-001', 'Apostle Islands',
'22 pristine islands in Lake Superior featuring sea caves, lighthouses, and incredible wilderness.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
46.7719, -90.7865,
'["Sea cave kayaking", "Lighthouse tours", "Island camping", "Ferry rides"]',
'2 days'),

('gl-duluth', 'gl-001', 'Duluth',
'Historic port city with aerial lift bridge, Great Lakes maritime museum, and scenic lakefront.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
46.7867, -92.1005,
'["Aerial Lift Bridge", "Great Lakes Aquarium", "Maritime museum", "Canal Park"]',
'1-2 days'),

('gl-sleeping', 'gl-001', 'Sleeping Bear Dunes',
'Massive sand dunes overlooking Lake Michigan with scenic drives and challenging climbs.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
44.8619, -86.0581,
'["Dune climbing", "Scenic drives", "Lake Michigan beaches", "Historic villages"]',
'Full day');

-- Insert trip places for San Francisco City Explorer
INSERT INTO trip_places (id, trip_id, name, description, image, lat, lng, activities, best_time_to_visit) VALUES
('sf-golden-gate', 'sf-001', 'Golden Gate Bridge',
'World-famous suspension bridge offering spectacular views and photo opportunities.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
37.8199, -122.4783,
'["Bridge walk", "Crissy Field", "Battery Spencer viewpoint", "Visitor center"]',
'Early morning or sunset'),

('sf-alcatraz', 'sf-001', 'Alcatraz Island',
'Former federal prison on an island with fascinating history and stunning city views.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
37.8267, -122.4233,
'["Prison tour", "Audio guide", "Island exploration", "Historical exhibits"]',
'Half day'),

('sf-fishermans', 'sf-001', 'Fisherman''s Wharf',
'Bustling waterfront district with sea lions, street performers, and fresh seafood.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
37.8080, -122.4177,
'["Pier 39", "Sea lions viewing", "Street performers", "Sourdough bread"]',
'Morning to afternoon'),

('sf-chinatown', 'sf-001', 'Chinatown',
'Largest Chinatown outside of Asia with authentic cuisine, shops, and cultural experiences.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
37.7941, -122.4078,
'["Dragon Gate", "Dim sum dining", "Herb shops", "Temple visits"]',
'Lunch and shopping'),

('sf-lombard', 'sf-001', 'Lombard Street',
'The world''s most crooked street with eight hairpin turns and beautiful gardens.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
37.8021, -122.4187,
'["Driving the curves", "Walking down", "Photography", "Russian Hill exploration"]',
'Any time');

-- Insert trip places for Yellowstone National Park
INSERT INTO trip_places (id, trip_id, name, description, image, lat, lng, activities, best_time_to_visit) VALUES
('ys-old-faithful', 'ys-001', 'Old Faithful',
'World''s most famous geyser that erupts approximately every 90 minutes.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
44.4605, -110.8281,
'["Geyser viewing", "Visitor center", "Upper Geyser Basin walk", "Old Faithful Inn"]',
'Multiple visits recommended'),

('ys-grand-canyon', 'ys-001', 'Grand Canyon of Yellowstone',
'Spectacular canyon with 308-foot Lower Falls and colorful rock formations.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
44.7197, -110.4983,
'["Artist Point viewing", "Canyon rim walks", "Lower Falls hike", "Photography"]',
'Morning light'),

('ys-mammoth', 'ys-001', 'Mammoth Hot Springs',
'Terraced limestone formations created by hot springs over thousands of years.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
44.9778, -110.7031,
'["Terraces boardwalk", "Fort Yellowstone", "Elk viewing", "Hot springs exploration"]',
'Any time'),

('ys-lamar', 'ys-001', 'Lamar Valley',
'America''s Serengeti - prime wildlife viewing area for bison, wolves, and bears.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
44.9167, -110.2833,
'["Wildlife spotting", "Photography", "Early morning drives", "Wolf watching"]',
'Dawn and dusk'),

('ys-yellowstone-lake', 'ys-001', 'Yellowstone Lake',
'Largest high-elevation lake in North America with pristine waters and mountain views.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
44.4167, -110.3833,
'["Lake activities", "Fishing", "Boat tours", "Scenic drives"]',
'Summer months');

-- Insert trip places for Grand Canyon National Park
INSERT INTO trip_places (id, trip_id, name, description, image, lat, lng, activities, best_time_to_visit) VALUES
('gc-south-rim', 'gc-001', 'South Rim',
'Most popular viewpoint with year-round access and stunning panoramic views of the canyon.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
36.0544, -112.1401,
'["Rim Trail walk", "Visitor center", "IMAX theater", "Multiple viewpoints"]',
'Sunrise and sunset'),

('gc-north-rim', 'gc-001', 'North Rim',
'Less crowded rim with different perspectives and cooler temperatures (seasonal access).',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
36.2078, -112.0576,
'["Bright Angel Point", "Lodge activities", "Hiking trails", "Photography"]',
'May - October only'),

('gc-bright-angel', 'gc-001', 'Bright Angel Trail',
'Well-maintained trail descending into the canyon with rest houses and water stations.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
36.0544, -112.1401,
'["Day hiking", "Rest house stops", "Mule rides", "Photography"]',
'Early morning start'),

('gc-desert-view', 'gc-001', 'Desert View',
'Eastern viewpoint featuring the historic Desert View Watchtower and Colorado River views.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
36.0419, -111.8261,
'["Watchtower climb", "River views", "Native American exhibits", "Sunset viewing"]',
'Late afternoon'),

('gc-hermits-rest', 'gc-001', 'Hermit''s Rest',
'Western end of Hermit Road with unique stone architecture and canyon views.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
36.0644, -112.2114,
'["Historic building tour", "Gift shop", "Trail access", "Bus tours"]',
'Afternoon');

-- Insert itineraries for Pacific Coast Highway
INSERT INTO trip_itinerary (trip_id, day, title, location, activities, highlights, estimated_time, driving_time) VALUES
('pch-001', 1, 'San Francisco Departure', 'San Francisco to Santa Cruz, CA',
'["Golden Gate Bridge photo stop", "Sausalito visit", "Drive scenic Highway 1", "Santa Cruz arrival"]',
'["Golden Gate Bridge", "Marin Headlands views", "Highway 1 coastal drive"]',
'6-8 hours', '3 hours'),

('pch-001', 2, 'Monterey Peninsula', 'Monterey, CA',
'["Monterey Bay Aquarium", "17-Mile Drive", "Carmel-by-the-Sea exploration", "Clint Eastwood''s mission ranch"]',
'["Sea otters and marine life", "Pebble Beach golf course", "Carmel''s fairy-tale cottages"]',
'Full day', '1 hour from Santa Cruz'),

('pch-001', 3, 'Big Sur Wilderness', 'Big Sur, CA',
'["McWay Falls hike", "Bixby Creek Bridge photos", "Nepenthe lunch with views", "Julia Pfeiffer Burns State Park"]',
'["80-foot waterfall", "Iconic bridge photography", "Coastal redwood forests"]',
'Full day', '2.5 hours scenic driving'),

('pch-001', 4, 'Hearst Castle & San Simeon', 'San Simeon, CA',
'["Hearst Castle guided tour", "Elephant seal colony viewing", "Moonstone Beach walk"]',
'["Opulent mansion rooms", "Wildlife viewing", "Beach combing"]',
'Half day', '2 hours from Big Sur'),

('pch-001', 5, 'Morro Bay Adventure', 'Morro Bay, CA',
'["Kayaking around Morro Rock", "Harbor walk and sea lions", "Fresh seafood dinner", "Sunset photography"]',
'["Morro Rock up close", "Harbor seals and sea otters", "Spectacular sunsets"]',
'Full day', '30 minutes from San Simeon'),

('pch-001', 6, 'Pismo Beach & Dunes', 'Pismo Beach, CA',
'["ATV riding in sand dunes", "Pismo Pier walk", "Clam chowder lunch", "Beach activities"]',
'["Oceano Dunes adventure", "Classic beach pier", "Famous clam chowder"]',
'Full day', '45 minutes from Morro Bay'),

('pch-001', 7, 'Santa Barbara Wine Country', 'Santa Barbara, CA',
'["Mission Santa Barbara visit", "State Street shopping", "Wine tasting tour", "Departure preparation"]',
'["Historic Spanish mission", "Mediterranean architecture", "World-class wineries"]',
'Full day', '2 hours from Pismo Beach');

-- Insert itineraries for Great Lakes Circle Tour
INSERT INTO trip_itinerary (trip_id, day, title, location, activities, highlights, driving_time) VALUES
('gl-001', 1, 'Chicago Departure', 'Chicago to Milwaukee, WI',
'["Lake Michigan shoreline drive", "Milwaukee brewery tours", "Historic Third Ward"]',
'["Lakefront views", "Craft beer culture", "Historic architecture"]',
'2 hours'),

('gl-001', 2, 'Wisconsin Dells', 'Wisconsin Dells, WI',
'["Scenic boat tours", "State parks exploration", "Local attractions"]',
'["Sandstone formations", "Wisconsin River", "Natural beauty"]',
'2 hours from Milwaukee'),

('gl-001', 3, 'Mackinac Island', 'Mackinac Island, MI',
'["Ferry to island", "Grand Hotel afternoon tea", "Horse-drawn carriage tour", "Fort Mackinac"]',
'["No cars policy", "Victorian charm", "Famous fudge shops"]',
'5 hours to Mackinaw City + ferry'),

('gl-001', 4, 'Upper Peninsula', 'Marquette, MI',
'["Pictured Rocks boat tour", "Munising Falls hike", "Lake Superior shoreline"]',
'["Multicolored cliffs", "Pristine waterfalls", "Largest Great Lake"]',
'4 hours'),

('gl-001', 5, 'Apostle Islands', 'Bayfield, WI',
'["Ferry to islands", "Sea cave kayaking", "Lighthouse visits"]',
'["22 pristine islands", "Ice caves (winter)", "Maritime history"]',
'3 hours'),

('gl-001', 6, 'Duluth Harbor', 'Duluth, MN',
'["Aerial Lift Bridge", "Great Lakes Aquarium", "Canal Park shopping"]',
'["Iconic lift bridge", "Maritime heritage", "Lake Superior views"]',
'2 hours'),

('gl-001', 7, 'Minnesota North Shore', 'Grand Portage, MN',
'["Scenic Highway 61", "State parks", "Waterfalls exploration"]',
'["Dramatic coastline", "Historic trading post", "Superior Hiking Trail"]',
'2.5 hours'),

('gl-001', 8, 'Michigan Upper Peninsula', 'Grand Marais, MI',
'["Grand Sable Dunes", "Log Slide", "Au Sable Light Station"]',
'["Massive sand dunes", "Historic lighthouse", "Pristine wilderness"]',
'4 hours'),

('gl-001', 9, 'Sleeping Bear Dunes', 'Traverse City, MI',
'["Dune climbing", "Pierce Stocking Scenic Drive", "Cherry orchards"]',
'["Epic dune views", "Lake Michigan overlooks", "Local cherries"]',
'5 hours'),

('gl-001', 10, 'Return Journey', 'Chicago, IL',
'["Michigan lakefront drive", "Final Great Lakes views", "Chicago arrival"]',
'["Completion of circle tour", "Reflection on journey", "Urban contrast"]',
'4 hours');

-- Insert itineraries for San Francisco City Explorer
INSERT INTO trip_itinerary (trip_id, day, title, location, activities, highlights, estimated_time) VALUES
('sf-001', 1, 'Iconic Landmarks', 'Golden Gate & Fisherman''s Wharf',
'["Golden Gate Bridge walk", "Crissy Field picnic", "Fisherman''s Wharf lunch", "Pier 39 sea lions"]',
'["Bridge photography", "Waterfront dining", "Sea lion entertainment"]',
'Full day'),

('sf-001', 2, 'Alcatraz & North Beach', 'Alcatraz Island & Italian District',
'["Alcatraz prison tour", "North Beach Italian lunch", "Coit Tower visit", "Washington Square"]',
'["Prison history", "Italian culture", "City views from tower"]',
'Full day'),

('sf-001', 3, 'Chinatown & Union Square', 'Cultural Districts',
'["Chinatown walking tour", "Dim sum lunch", "Union Square shopping", "Cable car rides"]',
'["Authentic Chinese culture", "Shopping district", "Historic transportation"]',
'Full day'),

('sf-001', 4, 'Neighborhoods Explorer', 'Castro, Haight & Mission',
'["Castro District history", "Haight-Ashbury hippie culture", "Mission District murals", "Local dining"]',
'["LGBTQ history", "1960s culture", "Street art", "Diverse cuisine"]',
'Full day'),

('sf-001', 5, 'Golden Gate Park & Sunset', 'Park & Ocean',
'["Japanese Tea Garden", "de Young Museum", "Ocean Beach walk", "Sunset at Lands End"]',
'["Peaceful gardens", "World-class art", "Pacific Ocean", "Dramatic coastline"]',
'Full day');

-- Insert itineraries for Yellowstone National Park
INSERT INTO trip_itinerary (trip_id, day, title, location, activities, highlights, driving_time) VALUES
('ys-001', 1, 'South Entrance & Old Faithful', 'Old Faithful Area',
'["Park entry via South Gate", "Old Faithful geyser viewing", "Upper Geyser Basin walk", "Old Faithful Inn tour"]',
'["First geyser eruption", "Geyser basin exploration", "Historic lodge"]',
'Varies by origin'),

('ys-001', 2, 'Grand Loop Lower', 'Grand Canyon of Yellowstone',
'["Artist Point sunrise", "Lower Falls viewing", "Canyon rim trail", "Hayden Valley wildlife"]',
'["Iconic waterfall views", "Colorful canyon walls", "Bison herds"]',
'2 hours from Old Faithful'),

('ys-001', 3, 'Wildlife & Geothermal', 'Lamar Valley & Mammoth',
'["Dawn wildlife safari in Lamar", "Mammoth Hot Springs terraces", "Fort Yellowstone", "Elk viewing"]',
'["Wolf and bear spotting", "Unique limestone terraces", "Historic fort"]',
'1.5 hours between areas'),

('ys-001', 4, 'Yellowstone Lake', 'Lake Area',
'["West Thumb Geyser Basin", "Lake Hotel visit", "Fishing opportunities", "Scenic lake drives"]',
'["Lakeside geysers", "Historic hotel", "Mountain reflections"]',
'1 hour from Canyon'),

('ys-001', 5, 'Backcountry Adventure', 'Various Trails',
'["Choose hiking trail", "Backcountry exploration", "Photography opportunities", "Ranger programs"]',
'["Wilderness experience", "Less crowded areas", "Advanced photography"]',
'Full day hiking'),

('ys-001', 6, 'Final Exploration', 'Revisit Favorites',
'["Return to favorite spots", "Last-minute wildlife viewing", "Souvenir shopping", "Park departure"]',
'["Favorite locations", "Final photos", "Memories"]',
'Departure day');

-- Insert itineraries for Grand Canyon National Park
INSERT INTO trip_itinerary (trip_id, day, title, location, activities, highlights, driving_time) VALUES
('gc-001', 1, 'South Rim Arrival', 'Grand Canyon Village',
'["Park entry and orientation", "Visitor center exploration", "Rim Trail walk", "Sunset at Hopi Point"]',
'["First canyon views", "Park orientation", "Spectacular sunset"]',
'Varies by origin'),

('gc-001', 2, 'Canyon Exploration', 'South Rim Viewpoints',
'["Sunrise at Mather Point", "Desert View Drive", "Watchtower climb", "Bright Angel Trail hike"]',
'["Golden hour photography", "Historical watchtower", "Canyon descent"]',
'1 hour scenic drive'),

('gc-001', 3, 'Western Views', 'Hermit Road',
'["Hermit Road shuttle tour", "Multiple viewpoint stops", "Hermit''s Rest visit", "Photography workshop"]',
'["Varied canyon perspectives", "Historic architecture", "Photography skills"]',
'Full day shuttle tour'),

('gc-001', 4, 'Adventure Day', 'Choose Your Adventure',
'["Options: helicopter tour, river rafting, extended hiking, or mule ride", "Final viewpoint visits"]',
'["Unique canyon experience", "Personal adventure choice", "Final memories"]',
'Full or half day');

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_trip_places_trip_id ON trip_places(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_itinerary_trip_id ON trip_itinerary(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_itinerary_day ON trip_itinerary(trip_id, day);
CREATE INDEX IF NOT EXISTS idx_suggested_trips_slug ON suggested_trips(slug);
CREATE INDEX IF NOT EXISTS idx_suggested_trips_difficulty ON suggested_trips(difficulty);

-- Add some helpful views
CREATE OR REPLACE VIEW trip_summary AS
SELECT 
  st.id,
  st.slug,
  st.title,
  st.summary,
  st.duration,
  st.difficulty,
  st.estimated_cost,
  st.hero_image,
  st.tags,
  COUNT(tp.id) as place_count,
  COUNT(ti.id) as itinerary_days
FROM suggested_trips st
LEFT JOIN trip_places tp ON st.id = tp.trip_id
LEFT JOIN trip_itinerary ti ON st.id = ti.trip_id
GROUP BY st.id, st.slug, st.title, st.summary, st.duration, st.difficulty, st.estimated_cost, st.hero_image, st.tags;

COMMENT ON TABLE suggested_trips IS 'Pre-defined trip templates with detailed information';
COMMENT ON TABLE trip_places IS 'Points of interest and places to visit for each suggested trip';
COMMENT ON TABLE trip_itinerary IS 'Day-by-day itinerary for each suggested trip';
COMMENT ON VIEW trip_summary IS 'Summary view of trips with place and itinerary counts';