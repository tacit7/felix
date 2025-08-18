Here's my analysis of the POI discovery algorithm:

## Core Algorithm: Route Sampling + Circular Searches

### **The Mathematical Problem**

- **Routes are linear** (a path from A to B)
- **Google Places searches are circular** (radius around a point)
- **Solution**: Convert the linear route into strategic circular search areas

### **Algorithm Steps**

1. **Route → Coordinates**: Decode Google's polyline into lat/lng points
2. **Sample Points**: Place search points every 35-40 miles along the route
3. **Concurrent Searches**: Search for POIs within 20-25 miles of each sample point
4. **Merge & Deduplicate**: Combine results, remove duplicates, filter by relevance

### **Key Parameters**

- **Sample Interval**: 35-40 miles (balance coverage vs API calls)
- **Search Radius**: 20-25 miles (catch POIs slightly off direct route)
- **Overlap Strategy**: Slight overlap between search circles prevents gaps
- **Concurrency**: 3-5 parallel API calls (respect Google's rate limits)

### **Technical Implementation**

```elixir
defmodule RouteWiseApi.POIDiscoveryService do
  def discover_pois_along_route(route_polyline, opts \\ []) do
    route_polyline
    |> decode_polyline()           # Convert to lat/lng coordinates
    |> sample_every_n_miles(40)    # Get search points every 40 miles
    |> search_pois_concurrently()  # Query Google Places API in parallel
    |> deduplicate_and_filter()    # Remove duplicates, filter by rating
  end
end
```
