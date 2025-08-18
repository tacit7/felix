# RouteWise API Endpoint Examples

Complete request/response examples for all RouteWise API endpoints.

## Base URL
```
http://localhost:4001/api
```

## Authentication

### POST /auth/register
**Request:**
```json
{
  "user": {
    "username": "johndoe",
    "email": "john@example.com",
    "password": "securepassword123",
    "full_name": "John Doe"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "johndoe",
      "email": "john@example.com",
      "full_name": "John Doe",
      "provider": "local"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### POST /auth/login
**Request:**
```json
{
  "user": {
    "username": "johndoe",
    "password": "securepassword123"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "johndoe",
      "email": "john@example.com",
      "full_name": "John Doe"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

## Places & Search

### GET /places/autocomplete
**Request:**
```
GET /api/places/autocomplete?input=grand&limit=5&country=US
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "suggestions": [
      {
        "id": "uuid-here",
        "name": "Grand Canyon",
        "display_name": "Grand Canyon National Park, Arizona, United States",
        "lat": 36.0544,
        "lon": -112.1401,
        "type": 5,
        "type_name": "poi",
        "country_code": "US",
        "admin1_code": "US-AZ",
        "address": "Grand Canyon National Park, AZ, USA",
        "source": "local",
        "popularity_score": 95
      }
    ],
    "count": 1,
    "sources_used": ["local"]
  },
  "cache_info": {
    "status": "hit",
    "ttl": 285
  }
}
```

### GET /explore-results (by location)
**Request:**
```
GET /api/explore-results?location=Isla Verde Puerto Rico&source=auto&radius=10000
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "pois": [
      {
        "id": "ChIJXYZ123",
        "name": "El San Juan Hotel",
        "category": "hotel",
        "rating": 4.2,
        "address": "6063 Isla Verde Ave, Carolina, PR 00979",
        "lat": 18.4494,
        "lon": -66.0208,
        "image": "https://maps.googleapis.com/...",
        "source": "google",
        "price_level": 4,
        "reviews_count": 1250
      }
    ],
    "location": "Isla Verde, Puerto Rico",
    "location_coords": { "lat": 18.4494, "lng": -66.0208 },
    "bounds": {
      "north": 18.4600, "south": 18.4400,
      "east": -66.0100, "west": -66.0300
    },
    "maps_api_key": "AIza...",
    "meta": {
      "total_pois": 25,
      "location": "Isla Verde, Puerto Rico",
      "maps_available": true,
      "bounds_source": "calculated"
    }
  },
  "cache_info": {
    "status": "partial_hit"
  }
}
```

### GET /explore-results (by place_id from autocomplete)
**Request:**
```
GET /api/explore-results?place_id=550e8400-e29b-41d4-a716-446655440000&source=auto&radius=15000
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "pois": [
      {
        "id": "ChIJXYZ789",
        "name": "Grand Canyon Visitor Center",
        "category": "attraction",
        "rating": 4.6,
        "address": "Grand Canyon Village, AZ 86023",
        "lat": 36.0579,
        "lon": -112.1403,
        "image": "https://maps.googleapis.com/...",
        "source": "google",
        "price_level": null,
        "reviews_count": 2150
      }
    ],
    "location": "Grand Canyon",
    "location_coords": { "lat": 36.0544, "lng": -112.1401 },
    "bounds": {
      "north": 36.1044, "south": 36.0044,
      "east": -112.0901, "west": -112.1901
    },
    "maps_api_key": "AIza...",
    "meta": {
      "total_pois": 18,
      "location": "Grand Canyon",
      "place_id": "550e8400-e29b-41d4-a716-446655440000",
      "place_type": 5,
      "maps_available": true,
      "bounds_source": "cached_place",
      "from_cache": true
    }
  },
  "cache_info": {
    "status": "hit"
  }
}
```

### GET /places/search
**Request:**
```
GET /api/places/search?query=restaurants&lat=40.7128&lon=-74.0060&radius=5000
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "places": [
      {
        "id": "ChIJXYZ789",
        "name": "Joe's Pizza",
        "formatted_address": "123 Broadway, New York, NY 10001",
        "latitude": 40.7589,
        "longitude": -73.9851,
        "rating": 4.3,
        "price_level": 2,
        "place_types": ["restaurant", "food", "point_of_interest"],
        "opening_hours": {
          "open_now": true,
          "weekday_text": ["Monday: 11:00 AM – 11:00 PM", "..."]
        }
      }
    ],
    "next_page_token": "CmRaAAAA...",
    "total_results": 150
  }
}
```

## OpenStreetMap Integration

### GET /osm/nearby
**Request:**
```
GET /api/osm/nearby?lat=40.7128&lon=-74.0060&radius=5000&categories=restaurant,attraction
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "places": [
      {
        "osm_id": "way/123456789",
        "name": "Central Park",
        "category": "attraction",
        "subcategory": "park",
        "lat": 40.7829,
        "lon": -73.9654,
        "address": "New York, NY",
        "tags": {
          "leisure": "park",
          "name": "Central Park",
          "website": "https://www.centralparknyc.org"
        }
      }
    ],
    "total_count": 45,
    "search_radius": 5000,
    "coverage_score": 0.85
  }
}
```

## Routes & Navigation

### POST /routes/calculate
**Request:**
```json
{
  "origin": "New York, NY",
  "destination": "Boston, MA",
  "waypoints": ["Hartford, CT"],
  "travel_mode": "driving",
  "optimize_waypoints": true
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "routes": [
      {
        "summary": "I-95 N",
        "legs": [
          {
            "start_location": { "lat": 40.7128, "lng": -74.0060 },
            "end_location": { "lat": 41.7658, "lng": -72.6734 },
            "distance": { "text": "120 mi", "value": 193121 },
            "duration": { "text": "2 hours 15 mins", "value": 8100 }
          }
        ],
        "overview_polyline": {
          "points": "a~l~Fjk~uOwHJy@P"
        },
        "bounds": {
          "northeast": { "lat": 42.3601, "lng": -71.0589 },
          "southwest": { "lat": 40.7128, "lng": -74.0060 }
        }
      }
    ],
    "total_distance": "215 mi",
    "total_duration": "4 hours 2 mins"
  }
}
```

### POST /routes/wizard
**Request:**
```json
{
  "start_location": "San Francisco, CA",
  "end_location": "Los Angeles, CA",
  "travel_dates": {
    "start_date": "2024-06-15",
    "end_date": "2024-06-18"
  },
  "interests": ["beaches", "restaurants", "museums"],
  "budget": "moderate",
  "group_size": 2
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "route": {
      "waypoints": [
        { "name": "Monterey Bay", "lat": 36.6002, "lng": -121.8947 },
        { "name": "San Luis Obispo", "lat": 35.2828, "lng": -120.6596 }
      ],
      "total_distance": "382 mi",
      "total_duration": "6 hours 45 mins"
    },
    "suggested_pois": [
      {
        "name": "Monterey Bay Aquarium",
        "category": "museum",
        "match_score": 0.95
      }
    ],
    "estimated_costs": {
      "fuel": "$65",
      "accommodation": "$240",
      "food": "$180",
      "total": "$485"
    }
  }
}
```

## Trips Management

### POST /trips
**Request:**
```json
{
  "trip": {
    "name": "California Coast Road Trip",
    "description": "Epic coastal drive from SF to LA",
    "start_date": "2024-06-15",
    "end_date": "2024-06-18",
    "is_public": true,
    "route_data": {
      "start_location": "San Francisco, CA",
      "end_location": "Los Angeles, CA",
      "waypoints": ["Monterey, CA", "San Luis Obispo, CA"]
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "trip": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "California Coast Road Trip",
      "description": "Epic coastal drive from SF to LA",
      "start_date": "2024-06-15",
      "end_date": "2024-06-18",
      "is_public": true,
      "user_id": "550e8400-e29b-41d4-a716-446655440001",
      "created_at": "2024-08-15T20:45:00.000Z",
      "route_data": {
        "total_distance": "382 mi",
        "total_duration": "6 hours 45 mins"
      }
    }
  }
}
```

### GET /trips
**Request (Authenticated):**
```
GET /api/trips
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "trips": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "California Coast Road Trip",
        "description": "Epic coastal drive from SF to LA",
        "start_date": "2024-06-15",
        "end_date": "2024-06-18",
        "is_public": true,
        "created_at": "2024-08-15T20:45:00.000Z"
      }
    ],
    "total_count": 1,
    "page": 1,
    "per_page": 20
  }
}
```

## User Interests

### GET /interests/categories
**Request:**
```
GET /api/interests/categories
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "categories": [
      {
        "id": 1,
        "name": "outdoor",
        "display_name": "Outdoor Activities",
        "description": "Hiking, camping, national parks",
        "icon_name": "mountain",
        "is_active": true
      },
      {
        "id": 2,
        "name": "culture",
        "display_name": "Arts & Culture",
        "description": "Museums, galleries, historical sites",
        "icon_name": "palette",
        "is_active": true
      }
    ]
  }
}
```

### POST /interests
**Request (Authenticated):**
```json
{
  "interests": [
    {
      "category_id": 1,
      "is_enabled": true,
      "priority": 1
    },
    {
      "category_id": 2,
      "is_enabled": true,
      "priority": 2
    }
  ]
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "interests": [
      {
        "id": 1,
        "user_id": "550e8400-e29b-41d4-a716-446655440001",
        "category_id": 1,
        "is_enabled": true,
        "priority": 1,
        "category": {
          "name": "outdoor",
          "display_name": "Outdoor Activities"
        }
      }
    ]
  }
}
```

## Health & Monitoring

### GET /health
**Request:**
```
GET /api/health
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "service": "routewise-api",
    "version": "1.0.0",
    "status": "healthy",
    "timestamp": "2024-08-15T20:45:00.000Z",
    "checks": {
      "database": "healthy",
      "external_apis": {
        "google_places": "healthy",
        "locationiq": "healthy"
      }
    },
    "uptime": "2 days, 14 hours"
  }
}
```

## Error Responses

### 400 Bad Request
```json
{
  "status": "error",
  "message": "Invalid request parameters",
  "details": {
    "input": ["Input must be at least 2 characters"],
    "limit": ["Limit must be between 1 and 50"]
  }
}
```

### 401 Unauthorized
```json
{
  "status": "error",
  "message": "Authentication required",
  "details": {
    "code": "MISSING_TOKEN"
  }
}
```

### 404 Not Found
```json
{
  "status": "error",
  "message": "Trip not found",
  "details": {
    "trip_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 500 Internal Server Error
```json
{
  "status": "error",
  "message": "Internal server error",
  "details": {
    "code": "EXTERNAL_API_TIMEOUT",
    "service": "google_places"
  }
}
```

## Response Headers

All API responses include these headers:
```
Content-Type: application/json
X-Response-Time: 145ms
X-Request-ID: req_1234567890abcdef
Cache-Control: public, max-age=300
```

## Rate Limiting

Rate limits are applied per endpoint:
- **Authentication**: 10 requests per minute
- **Search/Autocomplete**: 100 requests per minute  
- **POI/Places**: 50 requests per minute
- **Trips**: 30 requests per minute
- **General**: 200 requests per minute

Rate limit headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1629900000
```

## Caching

Cache control information is included in responses:
```json
{
  "cache_info": {
    "status": "hit|miss|partial_hit",
    "ttl": 285,
    "source": "local|redis|external_api"
  }
}
```