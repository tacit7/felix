# Database Schema Documentation

## Overview

RouteWise Phoenix backend database schema documentation covering the core tables for places and POIs (Points of Interest). The database uses PostgreSQL with PostGIS extension for geospatial data.

**Current Status:**
- Places: 91 records (active table with imported data)
  - Puerto Rico: 41 places with enriched descriptions and travel details
  - Isla Verde: Restaurant data imported from TripAdvisor scraping
  - NYC: Test data (scheduled for removal)
- POIs: 0 records (legacy table, replaced by places)

## Tables

### Places Table

The `places` table is the primary storage for location data, integrating Google Places API, LocationIQ, and TripAdvisor data.

#### Schema Structure

```sql
CREATE TABLE places (
  id                   BIGINT PRIMARY KEY DEFAULT nextval('places_new_id_seq'),
  google_place_id      VARCHAR(255),
  name                 VARCHAR(255),
  formatted_address    VARCHAR(255),
  latitude             NUMERIC(10,6),
  longitude            NUMERIC(10,6),
  place_types          VARCHAR(255)[] DEFAULT ARRAY[]::VARCHAR[],
  rating               NUMERIC(3,2),
  price_level          INTEGER,
  phone_number         VARCHAR(255),
  website              VARCHAR(255),
  opening_hours        JSONB,
  photos               JSONB[] DEFAULT ARRAY[]::JSONB[],
  reviews_count        INTEGER DEFAULT 0,
  google_data          JSONB DEFAULT '{}'::JSONB,
  cached_at            TIMESTAMP(0) NOT NULL,
  inserted_at          TIMESTAMP(0) NOT NULL,
  updated_at           TIMESTAMP(0) NOT NULL,
  location             GEOMETRY(Point,4326),
  location_iq_place_id VARCHAR(255),
  location_iq_data     JSONB,
  description          TEXT,
  popularity_score     INTEGER DEFAULT 0,
  last_updated         TIMESTAMP(0),
  wiki_image           VARCHAR(255),
  search_vector        TSVECTOR,
  tripadvisor_url      VARCHAR(255)
);
```

#### Column Descriptions

**Core Identification:**
- `id` - Primary key, auto-incrementing bigint
- `google_place_id` - Unique identifier from Google Places API (indexed, unique)
- `location_iq_place_id` - LocationIQ place identifier for geocoding fallback

**Basic Information:**
- `name` - Place name (e.g., "Franklin Barbecue", "Zilker Park")
- `formatted_address` - Full address string from Google Places
- `description` - Extended description text with visitor tips, accessibility info, and travel details
- `place_types` - Array of place categories (e.g., ["restaurant", "food", "establishment"])

**Geographic Data:**
- `latitude` / `longitude` - Decimal coordinates (NUMERIC for precision)
- `location` - PostGIS Point geometry in WGS84 (SRID 4326) for spatial queries

**Business Information:**
- `rating` - Average rating (0.0-5.0, 2 decimal places)
- `reviews_count` - Number of reviews (default 0)
- `price_level` - Cost level (1-4, Google Places standard)
- `popularity_score` - Calculated popularity ranking (default 0)
- `phone_number` - Contact phone number
- `website` - Official website URL

**Operational Data:**
- `opening_hours` - JSONB with structured hours data from Google Places
- `photos` - Array of JSONB photo objects from Google Places

**External Integrations:**
- `google_data` - Complete Google Places API response (JSONB, default empty object)
- `location_iq_data` - LocationIQ API response data (JSONB)
- `tripadvisor_url` - TripAdvisor page URL for additional info
- `wiki_image` - Wikipedia/Wikimedia image URL

**Search & Performance:**
- `search_vector` - Full-text search vector (automatically maintained by trigger)
- `cached_at` - When data was last cached from external APIs
- `last_updated` - Manual update timestamp
- `inserted_at` / `updated_at` - Phoenix timestamps

#### Indexes & Performance

**Primary Indexes:**
```sql
-- Primary key
"places_new_pkey" PRIMARY KEY, btree (id)

-- Unique constraints
"places_new_google_place_id_index" UNIQUE, btree (google_place_id)
```

**Geographic Indexes:**
```sql
-- Spatial queries (PostGIS)
"places_location_gist_idx" gist (location)

-- Coordinate lookups
"places_new_latitude_longitude_index" btree (latitude, longitude)
```

**Search & Filtering:**
```sql
-- Full-text search
"places_search_vector_idx" gin (search_vector)

-- Category filtering
"places_new_place_types_index" btree (place_types)
"places_place_types_index" gin (place_types)  -- Array search

-- Rating/quality filtering
"places_new_rating_index" btree (rating)
"places_rating_reviews_count_index" btree (rating, reviews_count)
"places_popularity_score_index" btree (popularity_score)
```

**Cache & External Data:**
```sql
-- Cache management
"places_new_cached_at_index" btree (cached_at)
"places_last_updated_index" btree (last_updated)

-- External service lookups
"places_location_iq_place_id_index" btree (location_iq_place_id)
"places_tripadvisor_url_index" btree (tripadvisor_url)
```

#### Database Triggers

**Location Trigger:**
```sql
places_location_trigger BEFORE INSERT OR UPDATE ON places 
FOR EACH ROW EXECUTE FUNCTION update_places_location()
```
- Automatically maintains PostGIS `location` column from `latitude`/`longitude`
- Ensures spatial data consistency

**Search Trigger:**
```sql
places_search_trigger BEFORE INSERT OR UPDATE ON places 
FOR EACH ROW EXECUTE FUNCTION update_places_search()
```
- Automatically updates `search_vector` from `name`, `formatted_address`, and `description`
- Enables full-text search across place data

#### Data Sources

**Google Places API:**
- Primary data source for most fields
- Provides ratings, reviews, photos, hours
- Data cached in `google_data` JSONB field

**LocationIQ API:**
- Geocoding fallback for places without coordinates
- Alternative address formatting
- Stored in `location_iq_data` field

**TripAdvisor:**
- Enhanced URLs for tourism information
- Scraped and matched by place name/location
- Stored in `tripadvisor_url` field

**Manual/Curated:**
- Wikipedia images for enhanced presentation
- Popularity scoring based on user interactions
- Custom descriptions for featured places

### POIs Table (Legacy)

The `pois` table was the original Points of Interest storage but has been superseded by the `places` table. Currently empty (0 records) but maintained for backward compatibility.

#### Schema Structure

```sql
CREATE TABLE pois (
  id              BIGINT PRIMARY KEY DEFAULT nextval('pois_id_seq'),
  name            VARCHAR(255) NOT NULL,
  description     TEXT NOT NULL,
  category        VARCHAR(255) NOT NULL,
  rating          NUMERIC(2,1) NOT NULL,
  review_count    INTEGER NOT NULL,
  time_from_start VARCHAR(255) NOT NULL,
  image_url       VARCHAR(255) NOT NULL,
  place_id        VARCHAR(255),
  address         VARCHAR(255),
  price_level     INTEGER,
  is_open         BOOLEAN,
  inserted_at     TIMESTAMP(0) NOT NULL,
  updated_at      TIMESTAMP(0) NOT NULL,
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL
);
```

#### Key Differences from Places

**Simpler Structure:**
- Fixed schema with required fields
- No JSONB storage for flexible data
- No PostGIS geometry (uses DOUBLE PRECISION coordinates)

**Missing Features:**
- No external API integration
- No full-text search capabilities
- No photo arrays or rich metadata
- No caching or update tracking

**Indexes:**
```sql
"pois_pkey" PRIMARY KEY, btree (id)
"pois_category_index" btree (category)
"pois_latitude_longitude_index" btree (latitude, longitude)
"pois_place_id_index" btree (place_id)
"pois_rating_index" btree (rating)
```

#### Migration Status

**Current State:**
- 0 records in POIs table
- All new place data goes to `places` table
- POIs table maintained for API backward compatibility

**Recommended Action:**
- Use `places` table for all new development
- Consider deprecating POIs endpoints in future API versions
- Maintain POIs table schema until frontend migration complete

## Usage Examples

### Geographic Queries (Places)

```sql
-- Find places within 10km of coordinates
SELECT name, formatted_address, rating 
FROM places 
WHERE ST_DWithin(location, ST_MakePoint(-97.7431, 30.2672)::geography, 10000);

-- Find nearest restaurants
SELECT name, rating, ST_Distance(location, ST_MakePoint(-97.7431, 30.2672)::geography) as distance
FROM places 
WHERE 'restaurant' = ANY(place_types)
ORDER BY location <-> ST_MakePoint(-97.7431, 30.2672)::geometry
LIMIT 10;
```

### Search Queries

```sql
-- Full-text search
SELECT name, formatted_address, rating
FROM places 
WHERE search_vector @@ plainto_tsquery('barbecue austin');

-- Category filtering
SELECT name, place_types, rating
FROM places 
WHERE place_types @> ARRAY['restaurant', 'food']
AND rating >= 4.0
ORDER BY rating DESC, reviews_count DESC;
```

### Cache Management

```sql
-- Find stale cache entries (older than 7 days)
SELECT google_place_id, name, cached_at
FROM places 
WHERE cached_at < NOW() - INTERVAL '7 days'
AND google_place_id IS NOT NULL;

-- Update cache timestamp
UPDATE places 
SET cached_at = NOW(), google_data = $1 
WHERE google_place_id = $2;
```

## Performance Considerations

### Query Optimization

**Spatial Queries:**
- Use PostGIS `location` column with GIST index for distance queries
- Prefer `<->` operator for nearest neighbor searches
- Use `ST_DWithin` with geography type for radius searches

**Text Search:**
- Use `search_vector` with GIN index for full-text search
- Triggers automatically maintain search vector
- Use `plainto_tsquery()` for user-friendly search terms

**Filtering:**
- Use GIN index on `place_types` for array containment queries
- Combine rating and review count indexes for quality filtering
- Use `cached_at` index for cache management queries

### Memory Usage

**JSONB Storage:**
- `google_data` can be large (2-5KB per record)
- `photos` array grows with place popularity
- Consider archiving old cache data if storage becomes issue

**Index Size:**
- PostGIS indexes are larger than btree
- GIN indexes on arrays and tsvector require more memory
- Monitor index usage and remove unused indexes

### Maintenance

**Cache Refresh:**
- Google Places data should be refreshed weekly
- LocationIQ data is more static, refresh monthly
- TripAdvisor URLs are relatively stable

**Statistics:**
- Run `ANALYZE places` after bulk imports
- Update table statistics weekly for optimal query plans
- Monitor slow queries and add indexes as needed

## Development Notes

### Adding New Place Data

```elixir
# Phoenix context function
def create_place(attrs) do
  %Place{}
  |> Place.changeset(attrs)
  |> Repo.insert()
end

# With Google Places integration
def create_from_google_place(place_data) do
  attrs = %{
    google_place_id: place_data["place_id"],
    name: place_data["name"],
    formatted_address: place_data["formatted_address"],
    latitude: place_data.dig("geometry", "location", "lat"),
    longitude: place_data.dig("geometry", "location", "lng"),
    place_types: place_data["types"],
    rating: place_data["rating"],
    price_level: place_data["price_level"],
    google_data: place_data,
    cached_at: DateTime.utc_now()
  }
  
  create_place(attrs)
end
```

### Search Integration

```elixir
# Full-text search with ranking
def search_places(query, limit \\ 20) do
  from p in Place,
    where: fragment("? @@ plainto_tsquery(?)", p.search_vector, ^query),
    order_by: [desc: fragment("ts_rank(?, plainto_tsquery(?))", p.search_vector, ^query)],
    limit: ^limit
end

# Geographic search
def nearby_places(lat, lng, radius_meters \\ 5000) do
  point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
  
  from p in Place,
    where: fragment("ST_DWithin(?, ?, ?)", p.location, ^point, ^radius_meters),
    order_by: fragment("? <-> ?", p.location, ^point)
end
```

This documentation covers the complete database schema for RouteWise's place data storage, including performance optimization, usage examples, and development guidelines.