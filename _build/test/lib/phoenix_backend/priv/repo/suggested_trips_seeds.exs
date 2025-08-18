# RouteWise Suggested Trips Seeds
# Run with: mix run priv/repo/suggested_trips_seeds.exs

alias RouteWiseApi.Repo

# Insert suggested trips using raw SQL for simplicity
IO.puts("🌟 Seeding suggested trips...")

suggested_trips_sql = """
INSERT INTO suggested_trips (id, slug, title, summary, description, duration, difficulty, best_time, estimated_cost, hero_image, tips, tags, is_active, featured_order, inserted_at, updated_at) VALUES
(1, 'pacific-coast-highway', 'Pacific Coast Highway Adventure', 
'Experience the breathtaking beauty of California''s iconic coastline with stunning ocean views, charming coastal towns, and unforgettable sunsets.',
'The Pacific Coast Highway is one of America''s most scenic drives, stretching along California''s rugged coastline from San Francisco to San Diego. This 7-day journey takes you through some of the most beautiful and iconic locations on the West Coast.',
'7 Days', 'Easy', 'April - October', '$1,500 - $2,500',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'{"Book Hearst Castle tours in advance","Check road conditions for Big Sur (sometimes closed)","Pack layers - coastal weather can be unpredictable","Make dinner reservations at popular restaurants","Fill up gas tank regularly - limited stations in Big Sur"}',
'{"Coastal Drive","Scenic","Photography","Nature","Easy Driving"}',
true, 1, NOW(), NOW()),

(2, 'great-lakes', 'Great Lakes Circle Tour',
'Discover the majesty of America''s inland seas with stunning lakeshores, charming coastal towns, and diverse ecosystems across multiple states.',
'The Great Lakes Circle Tour takes you around the world''s largest group of freshwater lakes, offering spectacular scenery, rich maritime history, and diverse cultural experiences across the northern United States.',
'10 Days', 'Moderate', 'May - September', '$2,000 - $3,500',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=1200&h=600&fit=crop',
'{"Pack warm clothes even in summer","Book island ferries in advance","Check lighthouse tour schedules","Prepare for variable lake weather","Consider camping reservations early"}',
'{"Lakes","Islands","Lighthouses","Nature","History"}',
true, 2, NOW(), NOW()),

(3, 'san-francisco', 'San Francisco City Explorer',
'Immerse yourself in the vibrant culture, iconic landmarks, and diverse neighborhoods of the City by the Bay.',
'San Francisco offers an incredible urban adventure with its famous hills, historic cable cars, world-class dining, and eclectic neighborhoods each with their own unique character.',
'5 Days', 'Easy', 'September - November', '$1,200 - $2,000',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'{"Layer clothing - weather changes quickly","Book Alcatraz tickets well in advance","Use public transportation - parking is difficult","Try local sourdough bread and Dungeness crab","Walk carefully on steep hills"}',
'{"Urban","Culture","Food","History","Architecture"}',
true, 3, NOW(), NOW()),

(4, 'yellowstone', 'Yellowstone National Park',
'Explore America''s first national park with geysers, hot springs, wildlife, and pristine wilderness across Wyoming, Montana, and Idaho.',
'Yellowstone National Park is a wonderland of geothermal features, diverse wildlife, and stunning landscapes. Home to Old Faithful and thousands of other geothermal features, it''s a true natural treasure.',
'6 Days', 'Moderate', 'May - September', '$1,000 - $1,800',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'{"Book accommodations a year in advance","Bring bear spray for hiking","Check road closures before visiting","Pack layers for temperature changes","Maintain safe distance from wildlife"}',
'{"National Park","Geysers","Wildlife","Hiking","Photography"}',
true, 4, NOW(), NOW()),

(5, 'grand-canyon', 'Grand Canyon National Park',
'Marvel at one of the world''s most spectacular natural wonders with breathtaking views, hiking trails, and geological history.',
'The Grand Canyon is a UNESCO World Heritage Site and one of the most visited national parks in America. Its immense size and colorful landscape offers visitors multiple ways to experience this natural wonder.',
'4 Days', 'Moderate', 'April - May, September - November', '$800 - $1,400',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&h=600&fit=crop',
'{"Start hiking early to avoid heat","Bring plenty of water and snacks","Wear layers - temperature varies by elevation","Book helicopter tours in advance","Respect wildlife and stay on trails"}',
'{"National Park","Hiking","Photography","Geology","Adventure"}',
true, 5, NOW(), NOW())
ON CONFLICT (slug) DO NOTHING;
"""

Repo.query!(suggested_trips_sql)

IO.puts("📍 Seeding trip places...")

trip_places_sql = """
INSERT INTO trip_places (trip_id, name, description, image, latitude, longitude, activities, best_time_to_visit, order_index, inserted_at, updated_at) VALUES
(1, 'San Francisco',
'Start your journey in the iconic City by the Bay with its famous Golden Gate Bridge, steep hills, and vibrant culture.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
37.7749, -122.4194,
'{"Golden Gate Bridge","Fishermans Wharf","Lombard Street","Alcatraz Island"}',
'Morning departure', 1, NOW(), NOW()),

(1, 'Monterey Bay',
'World-famous aquarium and scenic 17-Mile Drive through Pebble Beach with stunning coastal views.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
36.6002, -121.8947,
'{"Monterey Bay Aquarium","17-Mile Drive","Carmel-by-the-Sea","Cannery Row"}',
'Full day', 2, NOW(), NOW()),

(1, 'Big Sur',
'Dramatic cliffs meet crashing waves in this pristine wilderness area with towering redwoods and scenic hiking trails.',
'https://images.unsplash.com/photo-1539635278303-dd5c92632f4d?w=400&h=300&fit=crop',
36.2704, -121.8081,
'{"McWay Falls","Bixby Creek Bridge","Julia Pfeiffer Burns State Park","Nepenthe Restaurant"}',
'Sunrise to sunset', 3, NOW(), NOW()),

(1, 'Hearst Castle',
'Opulent mansion built by newspaper magnate William Randolph Hearst, featuring stunning architecture and art collections.',
'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
35.6850, -121.1681,
'{"Castle tours","Gardens exploration","Zebra viewing","Historic exhibits"}',
'Half day', 4, NOW(), NOW()),

(1, 'Morro Bay',
'Charming harbor town dominated by the iconic 576-foot tall Morro Rock, perfect for kayaking and seafood.',
'https://images.unsplash.com/photo-1469474968133-88c9c0ceadeb?w=400&h=300&fit=crop',
35.3659, -120.8507,
'{"Morro Rock","Kayaking","Harbor walks","Fresh seafood dining"}',
'Afternoon and sunset', 5, NOW(), NOW());
"""

Repo.query!(trip_places_sql)

IO.puts("🗓️  Seeding trip itineraries...")

trip_itinerary_sql = """
INSERT INTO trip_itinerary (trip_id, day, title, location, activities, highlights, estimated_time, driving_time, order_index, inserted_at, updated_at) VALUES
(1, 1, 'San Francisco Departure', 'San Francisco to Santa Cruz, CA',
'{"Golden Gate Bridge photo stop","Sausalito visit","Drive scenic Highway 1","Santa Cruz arrival"}',
'{"Golden Gate Bridge","Marin Headlands views","Highway 1 coastal drive"}',
'6-8 hours', '3 hours', 1, NOW(), NOW()),

(1, 2, 'Monterey Peninsula', 'Monterey, CA',
'{"Monterey Bay Aquarium","17-Mile Drive","Carmel-by-the-Sea exploration","Clint Eastwoods mission ranch"}',
'{"Sea otters and marine life","Pebble Beach golf course","Carmel fairy-tale cottages"}',
'Full day', '1 hour from Santa Cruz', 2, NOW(), NOW()),

(1, 3, 'Big Sur Wilderness', 'Big Sur, CA',
'{"McWay Falls hike","Bixby Creek Bridge photos","Nepenthe lunch with views","Julia Pfeiffer Burns State Park"}',
'{"80-foot waterfall","Iconic bridge photography","Coastal redwood forests"}',
'Full day', '2.5 hours scenic driving', 3, NOW(), NOW());
"""

Repo.query!(trip_itinerary_sql)

IO.puts("✅ Suggested trips seeding completed!")
IO.puts("   - 5 suggested trips")
IO.puts("   - 5 places for Pacific Coast Highway")  
IO.puts("   - 3 itinerary days for Pacific Coast Highway")
IO.puts("")
IO.puts("💡 You can query the data with:")
IO.puts("   SELECT * FROM suggested_trips;")
IO.puts("   SELECT * FROM trip_places WHERE trip_id = 1;")
IO.puts("   SELECT * FROM trip_itinerary WHERE trip_id = 1 ORDER BY day;")