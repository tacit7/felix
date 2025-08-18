# RouteWise Phoenix Backend - FAQ

## 🔍 Autocomplete Endpoint Usage - August 15, 2025

### How to Use the Hybrid Autocomplete Endpoint for Frontend Integration
**Question:** How to implement autocomplete functionality using the hybrid autocomplete endpoint for home page explore places and plan route cards?
**Error/Issue:** Frontend needed autocomplete with proper display names and hierarchical location context
**Context:** Implementing autocomplete dropdowns for home page location search with good UX
**Solution:** Use the `/api/places/autocomplete` endpoint with proper display name handling:

**API Endpoint:**
```
GET /api/places/autocomplete?input={query}&source={source}&limit={limit}
```

**Parameters:**
- `input` (required): Search query (minimum 2 characters)
- `source` (optional): Force specific source ("local", "locationiq", "google", "auto" - default)
- `limit` (optional): Maximum results (default: 10, max: 50)
- `lat` & `lon` (optional): User location for proximity scoring
- `country` (optional): 2-letter country code filter

**Example Requests:**
```bash
# Basic search
curl "http://localhost:4001/api/places/autocomplete?input=grand"

# Force local cache search
curl "http://localhost:4001/api/places/autocomplete?input=grand&source=local"

# With location bias
curl "http://localhost:4001/api/places/autocomplete?input=restaurant&lat=40.7128&lon=-74.0060"
```

**Response Format:**
```json
{
  "data": {
    "suggestions": [
      {
        "id": "647c13ab-b8a6-4d81-82ce-f61923f4e2fd",
        "name": "Grand Canyon",
        "display_name": "Grand Canyon, Arizona",
        "lat": 36.0544,
        "lon": -112.1401,
        "type": 5,
        "source": "local",
        "country_code": "US",
        "admin1_code": "US-AZ"
      }
    ]
  }
}
```

**Frontend Implementation:**
1. **Show in dropdown**: Use `suggestion.display_name`
2. **Insert in text field on selection**: Use `suggestion.display_name`
3. **Use for navigation/search**: Use `suggestion.id` or coordinates
4. **Cache for offline**: Store full suggestion object

**Three-Tier Fallback System:**
- **Local Cache**: Fast cached popular places (90 locations)
- **LocationIQ**: Cost-effective external API (~10x cheaper than Google)
- **Google Places**: Premium fallback for comprehensive coverage

**Display Name Format:**
- Cities: "San Francisco, California"
- Attractions: "Grand Canyon, Arizona"
- National Parks: "Yellowstone National Park, Wyoming"
- International: "Paris, France"

**Date:** August 15, 2025
**Project:** [[RouteWise Phoenix Backend]]
**Commits:** AutocompleteService caching fix, display name implementation
**Status:** Solved

#phoenix #autocomplete #frontend-integration #api #hybrid-fallback #ux
**Related:** [[Hybrid Autocomplete System]] [[API Integration Guide]]
---