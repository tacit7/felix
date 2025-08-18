# LocationIQ Route-Based POI Discovery Implementation Plan

**Status**: PLANNED - Ready for implementation in future session  
**Priority**: HIGH - Significant improvement to route intelligence  
**Dependencies**: LocationIQ API integration, spatial calculation libraries  
**Next Session**: Start with Phase 1 (LocationIQ Route Integration)

## Current State Assessment
- **Routing**: Using Google Directions API (GoogleDirections module)
- **Geocoding**: Using LocationIQ for city autocomplete, recently added to route-results/explore-results
- **POI Search**: Using Google Places API for radius-based searches
- **Limitation**: Current POI discovery is city-based only (start/end points), missing route coverage
- **Missing**: No POI center calculation or bounding box computation

## Core Algorithm: Route Sampling + Circular Searches

### Mathematical Problem
- Routes are linear (a path from A to B)
- Google Places searches are circular (radius around a point)
- **Solution**: Convert the linear route into strategic circular search areas

### Algorithm Steps
1. **Route → Coordinates**: Decode LocationIQ's polyline into lat/lng points
2. **Sample Points**: Place search points every 35-40 miles along the route
3. **Concurrent Searches**: Search for POIs within 20-25 miles of each sample point
4. **Merge & Deduplicate**: Combine results, remove duplicates, filter by relevance
5. **Spatial Analysis**: Calculate POI center, bounding box, route metrics

### Key Parameters
- **Sample Interval**: 35-40 miles (balance coverage vs API calls)
- **Search Radius**: 20-25 miles (catch POIs slightly off direct route)
- **Overlap Strategy**: Slight overlap between search circles prevents gaps
- **Concurrency**: 3-5 parallel API calls (respect LocationIQ's rate limits)

## Implementation Strategy: Hybrid LocationIQ + Google Approach

### Phase 1: LocationIQ Route Integration 
**Goal**: Get route polyline from LocationIQ instead of Google

#### 1. Create LocationIQ Directions Module
**File**: `lib/phoenix_backend/location_iq/directions.ex`

```elixir
defmodule RouteWiseApi.LocationIQ.Directions do
  @moduledoc """
  LocationIQ Directions API client for route calculations and polyline extraction.
  """
  
  @base_url "https://us1.locationiq.com/v1/directions"
  
  def get_route(origin, destination, opts \\ []) do
    # GET /directions/driving/{coordinates}
    # Returns: polyline geometry + route metadata
  end
  
  def get_route_alternatives(origin, destination, opts \\ []) do
    # Multiple route options
  end
  
  def optimize_waypoints(origin, destination, waypoints, opts \\ []) do
    # Optimized waypoint ordering
  end
end
```

#### 2. Add Polyline Decoding Utility
**File**: `lib/phoenix_backend/location_iq/polyline_decoder.ex`

```elixir
defmodule RouteWiseApi.LocationIQ.PolylineDecoder do
  @moduledoc """
  Decode LocationIQ polyline geometry into coordinate arrays.
  """
  
  def decode_polyline(encoded_polyline) do
    # Decode to list of %{lat: float, lng: float}
    # Handle LocationIQ's specific encoding format
  end
  
  def encode_polyline(coordinates) do
    # Encode coordinates back to polyline (for caching)
  end
end
```

#### 3. Add LocationIQ POI Search
**File**: Extend `lib/phoenix_backend/location_iq.ex`

```elixir
# Add to existing RouteWiseApi.LocationIQ module

def search_nearby(location, radius_meters, opts \\ []) do
  # Search POIs within radius of coordinates
  # Categories: restaurant, gas_station, lodging, tourist_attraction
  # Returns: POI results with place_id, name, category, rating, coordinates
end

def search_by_category(location, category, radius_meters, opts \\ []) do
  # Category-specific POI searches
end
```

### Phase 2: Route Sampling Algorithm
**Goal**: Convert linear route into strategic search points

#### 4. Create POI Discovery Service
**File**: `lib/phoenix_backend/poi_discovery_service.ex`

```elixir
defmodule RouteWiseApi.POIDiscoveryService do
  @moduledoc """
  Route-based POI discovery using strategic sampling and concurrent searches.
  """
  
  alias RouteWiseApi.LocationIQ.{Directions, PolylineDecoder}
  alias RouteWiseApi.{GeoUtils, POISpatialAnalysis}
  
  @sample_interval_miles 40
  @search_radius_meters 25_000  # 25km
  @max_concurrent_searches 5
  @poi_categories ["restaurant", "gas_station", "lodging", "tourist_attraction"]
  
  def discover_pois_along_route(start, destination, opts \\ []) do
    with {:ok, route_data} <- Directions.get_route(start, destination, opts),
         {:ok, coordinates} <- PolylineDecoder.decode_polyline(route_data.polyline),
         sample_points <- GeoUtils.sample_points_by_distance(coordinates, @sample_interval_miles),
         {:ok, pois} <- search_pois_concurrently(sample_points),
         deduplicated_pois <- deduplicate_and_filter(pois),
         spatial_analysis <- POISpatialAnalysis.analyze_poi_distribution(deduplicated_pois, coordinates) do
      
      {:ok, %{
        pois: deduplicated_pois,
        route_data: route_data,
        spatial_analysis: spatial_analysis,
        sample_points: sample_points
      }}
    else
      error -> error
    end
  end
  
  defp search_pois_concurrently(sample_points) do
    # Parallel LocationIQ POI searches with rate limiting
    sample_points
    |> Task.async_stream(&search_pois_at_point/1, max_concurrency: @max_concurrent_searches)
    |> Enum.reduce({:ok, []}, &collect_poi_results/2)
  end
  
  defp deduplicate_and_filter(pois) do
    pois
    |> Enum.uniq_by(& &1.place_id)
    |> Enum.filter(&has_valid_coordinates?/1)
    |> Enum.sort_by(& &1.rating, :desc)
    |> Enum.take(50)  # Limit to top 50 POIs
  end
end
```

#### 5. Add Geographic Utilities
**File**: `lib/phoenix_backend/geo_utils.ex`

```elixir
defmodule RouteWiseApi.GeoUtils do
  @moduledoc """
  Geographic calculations and utilities for route and POI analysis.
  """
  
  @earth_radius_km 6371
  
  def haversine_distance(%{lat: lat1, lng: lng1}, %{lat: lat2, lng: lng2}) do
    # Calculate distance between two points in kilometers
  end
  
  def sample_points_by_distance(coordinates, interval_miles) do
    # Sample points along route at specified mile intervals
    # Returns strategic search points for POI discovery
  end
  
  def calculate_centroid(points) when is_list(points) do
    # Geographic center of point cluster
  end
  
  def calculate_bounding_box(points) when is_list(points) do
    # Min/max lat/lng for map viewport
    %{
      north: max_lat,
      south: min_lat, 
      east: max_lng,
      west: min_lng
    }
  end
  
  def calculate_route_midpoint(coordinates) do
    # Center point of route polyline
  end
  
  def miles_to_meters(miles), do: miles * 1609.34
  def meters_to_miles(meters), do: meters / 1609.34
end
```

### Phase 3: POI Center & Metrics Calculation
**Goal**: Add intelligent center calculation and spatial analysis

#### 6. POI Spatial Analysis
**File**: `lib/phoenix_backend/poi_spatial_analysis.ex`

```elixir
defmodule RouteWiseApi.POISpatialAnalysis do
  @moduledoc """
  Spatial analysis for POI distribution along routes.
  Provides center calculation, bounding boxes, and viewport optimization.
  """
  
  alias RouteWiseApi.GeoUtils
  
  def analyze_poi_distribution(pois, route_polyline) do
    poi_coords = extract_poi_coordinates(pois)
    
    %{
      poi_center: GeoUtils.calculate_centroid(poi_coords),
      poi_bounding_box: GeoUtils.calculate_bounding_box(poi_coords),
      route_center: GeoUtils.calculate_route_midpoint(route_polyline),
      route_bounding_box: GeoUtils.calculate_bounding_box(route_polyline),
      poi_density_per_segment: analyze_density_distribution(pois, route_polyline),
      optimal_map_center: calculate_optimal_viewport(poi_coords, route_polyline),
      zoom_level_suggestion: suggest_zoom_level(poi_coords, route_polyline),
      poi_statistics: calculate_poi_statistics(pois)
    }
  end
  
  defp calculate_optimal_viewport(poi_coords, route_polyline) do
    # Weight POI center and route center for optimal map display
    # Factors: POI density, route importance, user focus areas
  end
  
  defp suggest_zoom_level(poi_coords, route_polyline) do
    # Calculate appropriate zoom based on:
    # - Bounding box size
    # - POI density  
    # - Route length
    # Returns suggested zoom level (1-20)
  end
  
  defp analyze_density_distribution(pois, route_polyline) do
    # Divide route into segments, calculate POI count per segment
    # Returns array of POI counts for route visualization
  end
  
  defp calculate_poi_statistics(pois) do
    %{
      total_pois: length(pois),
      categories_found: extract_unique_categories(pois),
      average_rating: calculate_average_rating(pois),
      rating_distribution: calculate_rating_distribution(pois)
    }
  end
end
```

### Phase 4: Integration & Enhancement
**Goal**: Integrate with existing endpoints + optional Google enhancement

#### 7. Update Route Results Controller
**File**: Modify `lib/phoenix_backend_web/controllers/route_results_controller.ex`

```elixir
# Replace fetch_pois_for_route/2 with:

defp fetch_pois_for_route(start_city, end_city) do
  case RouteWiseApi.POIDiscoveryService.discover_pois_along_route(start_city, end_city) do
    {:ok, %{pois: pois, spatial_analysis: spatial_analysis}} -> 
      Logger.info("🎯 Route-based POI discovery found #{length(pois)} POIs")
      {pois, spatial_analysis}
    {:error, reason} ->
      Logger.warning("POI discovery failed: #{reason}, falling back to city-based search")
      fallback_to_city_based_search(start_city, end_city)
  end
end

# Enhanced response payload:
response = %{
  success: true,
  data: %{
    pois: formatted_pois,
    route: enhanced_route_data,
    spatial_analysis: spatial_analysis,  # NEW
    maps_api_key: maps_api_key,
    meta: enhanced_meta
  },
  timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
}
```

#### 8. Enhanced Response Payload Structure
```json
{
  "success": true,
  "data": {
    "pois": [
      {
        "id": "123",
        "placeId": "poi_123",
        "name": "Buc-ee's Travel Center",
        "address": "New Braunfels, TX",
        "rating": "4.8",
        "category": "gas_station",
        "lat": 29.7030,
        "lng": -98.1245,
        "imageUrl": "https://...",
        "description": "Travel center • 4.8⭐"
      }
    ],
    "route": {
      "distance": "195 miles",
      "duration": "3 hours",
      "start_coords": {"lat": 30.267, "lng": -97.743},
      "end_coords": {"lat": 32.777, "lng": -96.797},
      "sample_points": [
        {"lat": 30.267, "lng": -97.743},
        {"lat": 30.485, "lng": -97.234},
        {"lat": 31.097, "lng": -96.875}
      ]
    },
    "spatial_analysis": {
      "poi_center": {"lat": 31.522, "lng": -97.270},
      "poi_bounding_box": {
        "north": 32.850, "south": 30.200,
        "east": -96.600, "west": -97.800
      },
      "route_center": {"lat": 31.522, "lng": -97.270},
      "optimal_map_center": {"lat": 31.522, "lng": -97.270},
      "zoom_level_suggestion": 8,
      "poi_distribution": {
        "total_pois": 47,
        "density_per_segment": [8, 12, 15, 9, 3],
        "categories_found": ["restaurant", "gas_station", "lodging", "attraction"],
        "average_rating": 4.2
      }
    },
    "maps_api_key": "AIza...",
    "meta": {
      "total_pois": 47,
      "route_distance": "195 miles",
      "route_duration": "3 hours",
      "maps_available": true,
      "discovery_method": "route_sampling"
    }
  },
  "timestamp": "2025-08-08T00:30:00Z"
}
```

### Phase 5: Caching & Performance
**Goal**: Production-ready performance and reliability

#### 9. Enhanced Caching Strategy
```elixir
defmodule RouteWiseApi.Caching.RoutePOIs do
  @moduledoc """
  Specialized caching for route-based POI discoveries.
  """
  
  def get_route_pois_cache(start, destination, waypoints \\ []) do
    cache_key = build_route_cache_key(start, destination, waypoints)
    RouteWiseApi.Caching.backend().get(cache_key)
  end
  
  def put_route_pois_cache(start, destination, waypoints, discovery_data) do
    cache_key = build_route_cache_key(start, destination, waypoints)
    # Cache for 2 hours - route-based discoveries change less frequently
    RouteWiseApi.Caching.backend().put(cache_key, discovery_data, ttl: :timer.hours(2))
  end
  
  defp build_route_cache_key(start, destination, waypoints) do
    waypoints_hash = :crypto.hash(:md5, inspect(waypoints)) |> Base.encode16()
    "route_pois:#{String.downcase(start)}:#{String.downcase(destination)}:#{waypoints_hash}"
  end
end
```

#### 10. Concurrency & Rate Limiting
- Integrate with existing LocationIQ rate limiter
- Concurrent POI searches with proper backpressure
- Circuit breaker pattern for API failures

### Phase 6: Testing & Validation
**Goal**: Comprehensive testing suite

#### Test Files to Create:
- `test/phoenix_backend/poi_discovery_service_test.exs`
- `test/phoenix_backend/poi_spatial_analysis_test.exs`
- `test/phoenix_backend/location_iq/directions_test.exs`
- `test/phoenix_backend/geo_utils_test.exs`

#### Test Scenarios:
```elixir
defmodule RouteWiseApi.POIDiscoveryServiceTest do
  describe "discover_pois_along_route/2" do
    test "Austin to Dallas route finds expected POIs" do
      # Test the full Austin → Dallas discovery
      # Verify Buc-ee's, San Marcos outlets are found
      # Check spatial analysis accuracy
    end
    
    test "handles short routes (< 40 miles)" do
      # Edge case: routes shorter than sample interval
    end
    
    test "handles API failures gracefully" do
      # LocationIQ down, rate limiting, etc.
    end
  end
end
```

## Technical Specifications

### Configuration Parameters
```elixir
config :phoenix_backend, RouteWiseApi.POIDiscoveryService,
  sample_interval_miles: 40,
  search_radius_meters: 25_000,
  max_concurrent_searches: 5,
  poi_categories: ["restaurant", "gas_station", "lodging", "tourist_attraction"],
  cache_ttl_hours: 2,
  fallback_enabled: true
  
config :phoenix_backend, RouteWiseApi.POISpatialAnalysis,
  poi_clustering_threshold: 2_000,  # 2km
  map_padding_factor: 0.1,          # 10% padding
  zoom_level_weights: %{
    poi_density: 0.4,
    route_length: 0.3,
    bounding_box_size: 0.3
  }
```

### Expected Performance
- **Austin → Dallas** (200 miles): 
  - 5 sample points = 5 LocationIQ POI searches
  - Expected response time: <2 seconds
  - POI count: 40-60 relevant POIs
  - Cache hit ratio: >80% after initial population

### API Call Volume Analysis
| Route Length | Sample Points | LocationIQ Calls | Current Calls | Improvement |
|-------------|---------------|------------------|---------------|-------------|
| 100 miles   | 3 points      | 3 searches       | 2 city       | +50% coverage |
| 200 miles   | 5 points      | 5 searches       | 2 city       | +150% coverage |
| 500 miles   | 13 points     | 13 searches      | 2 city       | +550% coverage |

## Files to Create/Modify

### New Files (10)
1. `lib/phoenix_backend/location_iq/directions.ex` - LocationIQ route integration
2. `lib/phoenix_backend/location_iq/polyline_decoder.ex` - Polyline decoding utilities  
3. `lib/phoenix_backend/poi_discovery_service.ex` - Core route sampling algorithm
4. `lib/phoenix_backend/poi_spatial_analysis.ex` - POI center & spatial calculations
5. `lib/phoenix_backend/geo_utils.ex` - Geographic utilities and math functions
6. `lib/phoenix_backend/caching/route_pois.ex` - Specialized route POI caching
7. `test/phoenix_backend/poi_discovery_service_test.exs` - Core service tests
8. `test/phoenix_backend/poi_spatial_analysis_test.exs` - Spatial analysis tests
9. `test/phoenix_backend/location_iq/directions_test.exs` - LocationIQ integration tests
10. `test/phoenix_backend/geo_utils_test.exs` - Geographic utility tests

### Modified Files (5)
1. `lib/phoenix_backend/location_iq.ex` - Add POI search functions
2. `lib/phoenix_backend_web/controllers/route_results_controller.ex` - Route-based POI integration
3. `lib/phoenix_backend_web/controllers/explore_results_controller.ex` - Add spatial analysis
4. `lib/phoenix_backend/route_service.ex` - LocationIQ integration
5. `lib/phoenix_backend/caching.ex` - Add route POI caching delegates

## Success Metrics & Validation

### Quality Metrics
- **POI Relevance**: >80% of discovered POIs should be route-relevant
- **Coverage**: Find POIs not discoverable by city-only search
- **Accuracy**: Spatial analysis within 5% of actual geographic centers

### Performance Metrics  
- **Response Time**: <2s for route + POI discovery + spatial analysis
- **Cache Hit Ratio**: >75% for repeated route queries
- **API Efficiency**: <15 LocationIQ calls per route discovery

### Example Success Cases
**Austin → Dallas Route Should Discover**:
- Buc-ee's Travel Center (New Braunfels) - Famous Texas travel stop
- San Marcos Premium Outlets - Major shopping destination  
- Waco attractions (Dr Pepper Museum, Magnolia Market)
- Round Rock outlets and restaurants
- Multiple gas stations and restaurants along I-35

**Spatial Analysis Should Provide**:
- Optimal map center for displaying route + POIs
- Appropriate zoom level (likely 7-9 for 200-mile route)
- POI distribution showing concentration around major cities
- Bounding box encompassing both route and POI cluster

## Implementation Phases Priority

### Phase 1: Core Foundation (Highest Priority)
- LocationIQ Directions integration  
- Basic polyline decoding
- Simple route sampling algorithm

### Phase 2: POI Discovery (High Priority)
- POI Discovery Service implementation
- Geographic utilities
- Basic concurrent searches

### Phase 3: Spatial Intelligence (Medium Priority) 
- POI center calculation
- Bounding box computation
- Optimal viewport calculation

### Phase 4: Performance & Polish (Medium Priority)
- Enhanced caching strategies
- Rate limiting integration
- Comprehensive error handling

### Phase 5: Testing & Documentation (Lower Priority)
- Comprehensive test suite
- Performance benchmarking
- Documentation updates

## Next Steps for Implementation

### Immediate Next Session Tasks:
1. **Start with LocationIQ Directions module** - Core foundation
2. **Implement polyline decoding** - Essential for coordinate extraction
3. **Build basic geo utilities** - Distance calculations and sampling
4. **Create simple route sampling** - Prove the core algorithm works

### Recommended Implementation Order:
1. Create `GeoUtils` module with distance calculations
2. Create `LocationIQ.Directions` module for route data
3. Create `PolylineDecoder` for coordinate extraction  
4. Build basic `POIDiscoveryService` with simple sampling
5. Test with Austin → Dallas route to validate approach
6. Add spatial analysis and POI center calculation
7. Integrate with existing controllers
8. Add comprehensive caching and performance optimization

### Validation Checkpoints:
- **Checkpoint 1**: Can we decode LocationIQ polylines correctly?
- **Checkpoint 2**: Does route sampling place points at correct intervals?
- **Checkpoint 3**: Do we discover route-relevant POIs (Buc-ee's test)?
- **Checkpoint 4**: Is spatial analysis providing useful center/bounds?
- **Checkpoint 5**: Are response times acceptable (<2s)?

This implementation will transform RouteWise from basic city-based POI search to intelligent route-aware POI discovery with spatial optimization.