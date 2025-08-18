# Geographic Bounds System

**Accurate search radius calculation using OpenStreetMap data for comprehensive POI coverage**

## Overview

The Geographic Bounds System replaces hardcoded search radius values with accurate geographic bounding boxes from OpenStreetMap (OSM) Nominatim API. This ensures appropriate POI coverage for different location types, from small cities (4km) to large territories (158km).

## Architecture

### Database Schema

```sql
-- Added to cities table
ALTER TABLE cities ADD COLUMN bbox_north DECIMAL(10,7);     -- Northernmost latitude
ALTER TABLE cities ADD COLUMN bbox_south DECIMAL(10,7);     -- Southernmost latitude  
ALTER TABLE cities ADD COLUMN bbox_east DECIMAL(10,7);      -- Easternmost longitude
ALTER TABLE cities ADD COLUMN bbox_west DECIMAL(10,7);      -- Westernmost longitude
ALTER TABLE cities ADD COLUMN search_radius_meters INTEGER; -- Calculated radius
ALTER TABLE cities ADD COLUMN bounds_source VARCHAR(255);   -- Data source ("osm", "manual")
ALTER TABLE cities ADD COLUMN bounds_updated_at TIMESTAMP;  -- Last update time
```

### Core Module: `RouteWiseApi.OSMGeocoding`

Free OpenStreetMap Nominatim API integration for fetching geographic bounds.

#### Key Functions

```elixir
# Fetch bounds from OSM Nominatim API
{:ok, bounds_data} = OSMGeocoding.fetch_bounds("Puerto Rico")
# Returns: %{
#   bbox_north: 18.67, bbox_south: 17.73,
#   bbox_east: -65.11, bbox_west: -68.11,
#   search_radius_meters: 158215,
#   display_name: "Puerto Rico",
#   source: "osm"
# }
```

#### Rate Limiting
- **1 request per second** (respectful of free service)
- **Automatic retry** with exponential backoff
- **Error handling** with graceful fallbacks

### Search Radius Calculation

Enhanced logic in `ExploreResultsController`:

```elixir
# Dynamic search radius with OSM data priority
base_search_radius = cond do
  # Use OSM geographic bounds data if available (most accurate)
  city.search_radius_meters && city.search_radius_meters > 0 ->
    city.search_radius_meters

  # Fallback to entity type-based radius
  true ->
    case Map.get(city, :type) || Map.get(city, :entity_type) do
      "national_park" -> 50_000  # 50km for national parks
      "state" -> 100_000         # 100km for states
      "country" -> 200_000       # 200km for countries
      "territory" -> 150_000     # 150km for territories
      _ -> 20_000                # 20km default for cities
    end
end
```

## Coverage Data

### Major US Cities (Top 10)

| City | OSM Radius | Previous | Improvement |
|------|------------|----------|-------------|
| New York City | 24km | 20km | +20% coverage |
| Los Angeles | 37km | 20km | +85% coverage |
| Chicago | 21km | 20km | +5% coverage |
| Houston | 43km | 20km | +115% coverage |
| Phoenix | 34km | 20km | +70% coverage |
| Philadelphia | 15km | 20km | -25% (more accurate) |
| San Antonio | 30km | 20km | +50% coverage |
| San Diego | 32km | 20km | +60% coverage |
| Dallas | 25km | 20km | +25% coverage |
| San Jose | 20km | 20km | Baseline |

### Popular Destinations

| Destination | OSM Radius | Type | Coverage Benefit |
|-------------|------------|------|------------------|
| Las Vegas | 15km | Tourist city | Focused coverage |
| Miami | 9km | Coastal city | Precise urban area |
| Seattle | 14km | Metro area | Compact coverage |
| Boston | 15km | Historic city | Urban boundaries |
| Denver | 21km | Mountain city | Extended metro |
| Austin, Texas | 23km | State capital | City limits |
| Nashville | 24km | Music city | Metro coverage |
| New Orleans | 24km | Cultural hub | Greater area |

### National Parks & Tourist Areas

| Location | OSM Radius | Type | Coverage |
|----------|------------|------|----------|
| Yellowstone National Park | 54km | National park | Full park coverage |
| Grand Canyon National Park | 107km | National park | Entire canyon area |
| Yosemite National Park | 38km | National park | Valley + surroundings |
| Orlando, Florida | 18km | Tourist destination | Theme parks included |
| Washington DC | 11km | Federal district | Metro area |
| Niagara Falls | 5km | Natural landmark | Falls + vicinity |
| Myrtle Beach | 8km | Beach destination | Coastal area |
| Key West | 4km | Island city | Island coverage |
| Martha's Vineyard | 16km | Island destination | Full island |

### Territory Coverage

| Territory | OSM Radius | Previous | Improvement |
|-----------|------------|----------|-------------|
| Puerto Rico | 158km | 150km | +8km (more accurate) |

## Implementation Benefits

### 🎯 Accurate POI Coverage
- **Territories**: Puerto Rico POI searches now cover the entire island (158km vs 150km hardcoded)
- **Large Cities**: Houston gets 43km radius instead of generic 20km (+115% coverage)
- **Small Areas**: Key West uses precise 4km radius instead of over-broad 20km
- **National Parks**: Grand Canyon gets appropriate 107km radius for full park coverage

### 💰 Cost Optimization  
- **Free API**: OpenStreetMap Nominatim is completely free
- **Rate Limited**: 1 request/second respects free service limits
- **Cached Results**: OSM data stored in database, no repeated API calls
- **Fallback Strategy**: Graceful degradation to type-based radius if OSM unavailable

### 🚀 Production Ready
- **Error Handling**: Comprehensive error handling with fallbacks
- **Data Validation**: Bounds validation and sanitization
- **Performance**: Cached results for fast lookups
- **Monitoring**: Source tracking and update timestamps

## API Usage

### Search Radius in Action

Before (hardcoded):
```bash
GET /api/explore-results?location=Houston
# Uses: 20km radius (generic city fallback)
# Returns: 12 POIs (limited coverage)
```

After (OSM bounds):
```bash
GET /api/explore-results?location=Houston  
# Uses: 43km radius (actual city boundaries)
# Returns: 28+ POIs (full metropolitan coverage)
```

### Bounds Data Access

Cities now include geographic bounds in API responses:

```json
{
  "id": "city-uuid",
  "name": "Houston",
  "display_name": "Houston, Texas, United States",
  "lat": 29.7604,
  "lon": -95.3698,
  "search_radius_meters": 43223,
  "bbox_north": 30.1103506,
  "bbox_south": 29.5370705,
  "bbox_east": -95.0120525,
  "bbox_west": -95.9097419,
  "bounds_source": "osm",
  "bounds_updated_at": "2025-08-17T01:22:15Z"
}
```

## Deployment Guide

### Database Migration

```bash
# Apply geographic bounds migration
mix ecto.migrate
```

### Environment Setup

No additional environment variables required - uses free OpenStreetMap API.

### Data Population

For new deployments, populate OSM bounds data:

```elixir
# Example: Update city with OSM bounds
case RouteWiseApi.OSMGeocoding.fetch_bounds("Austin, Texas") do
  {:ok, osm_data} ->
    city
    |> City.changeset(%{
      bbox_north: osm_data.bbox_north,
      bbox_south: osm_data.bbox_south,
      bbox_east: osm_data.bbox_east,
      bbox_west: osm_data.bbox_west,
      search_radius_meters: osm_data.search_radius_meters,
      bounds_source: "osm",
      bounds_updated_at: DateTime.utc_now()
    })
    |> Repo.update()
    
  {:error, reason} ->
    Logger.warning("Failed to fetch OSM bounds: #{reason}")
    # Falls back to type-based radius
end
```

### Monitoring

Monitor bounds data quality:

```sql
-- Check OSM bounds coverage
SELECT 
  bounds_source,
  COUNT(*) as city_count,
  AVG(search_radius_meters/1000) as avg_radius_km
FROM cities 
WHERE search_radius_meters IS NOT NULL 
GROUP BY bounds_source;

-- Find cities without bounds data
SELECT name, display_name, city_type 
FROM cities 
WHERE search_radius_meters IS NULL 
ORDER BY search_count DESC;
```

## Future Enhancements

### Automatic Updates
- **Periodic refresh** of OSM bounds data
- **Change detection** for updated city boundaries
- **Validation alerts** for significant radius changes

### Enhanced Coverage
- **International cities** with OSM bounds
- **State and county boundaries** for regional searches
- **Custom polygon support** for complex geographic areas

### Performance Optimization
- **Spatial indexing** for faster geographic queries
- **Cached calculations** for common search patterns
- **Background updates** to minimize API response times

## Technical Notes

### OSM Nominatim API
- **Endpoint**: `https://nominatim.openstreetmap.org/search`
- **Rate Limit**: 1 request/second
- **Data Format**: JSON with bounding box coordinates
- **Accuracy**: Based on OpenStreetMap community data

### Coordinate System
- **SRID**: 4326 (WGS84)
- **Latitude**: -90 to +90 degrees
- **Longitude**: -180 to +180 degrees
- **Precision**: 7 decimal places (approx. 1.1cm accuracy)

### Radius Calculation
```elixir
# Calculate radius from bounding box
def calculate_radius_from_bounds(bbox_north, bbox_south, bbox_east, bbox_west, center_lat) do
  # Calculate distances in meters
  lat_distance = (bbox_north - bbox_south) * 111_000  # ~111km per degree latitude
  lng_distance = (bbox_east - bbox_west) * 111_000 * :math.cos(center_lat * :math.pi / 180)
  
  # Return half the maximum dimension (radius from center)
  max(lat_distance, lng_distance) / 2
end
```

This system ensures accurate, scalable, and cost-effective geographic search capabilities for RouteWise's POI discovery features.