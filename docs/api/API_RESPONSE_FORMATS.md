# API Response Formats Documentation

Complete documentation of all API response formats used in RouteWise backend.

## Table of Contents

1. [Google Places API Responses](#google-places-api-responses)
2. [LocationIQ API Responses](#locationiq-api-responses)
3. [TripAdvisor Scraper Responses](#tripadvisor-scraper-responses)
4. [Internal API Responses](#internal-api-responses)
5. [POI Clustering API Responses](#poi-clustering-api-responses)
6. [Error Response Formats](#error-response-formats)

---

## Google Places API Responses

### Place Search Response
```json
{
  "results": [
    {
      "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
      "name": "Sydney Opera House",
      "formatted_address": "Bennelong Point, Sydney NSW 2000, Australia",
      "geometry": {
        "location": {
          "lat": -33.8567844,
          "lng": 151.2152967
        }
      },
      "types": ["tourist_attraction", "point_of_interest", "establishment"],
      "rating": 4.4,
      "user_ratings_total": 30421,
      "price_level": 2,
      "opening_hours": {
        "open_now": true,
        "weekday_text": [
          "Monday: 9:00 AM – 8:30 PM",
          "Tuesday: 9:00 AM – 8:30 PM"
        ]
      },
      "photos": [
        {
          "photo_reference": "CmRaAAAA...",
          "height": 1152,
          "width": 1536
        }
      ]
    }
  ],
  "status": "OK"
}
```

### Place Details Response
```json
{
  "result": {
    "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
    "name": "Sydney Opera House",
    "formatted_address": "Bennelong Point, Sydney NSW 2000, Australia",
    "formatted_phone_number": "(02) 9250 7111",
    "international_phone_number": "+61 2 9250 7111",
    "website": "https://www.sydneyoperahouse.com/",
    "geometry": {
      "location": {
        "lat": -33.8567844,
        "lng": 151.2152967
      }
    },
    "types": ["tourist_attraction", "point_of_interest", "establishment"],
    "rating": 4.4,
    "user_ratings_total": 30421,
    "price_level": 2,
    "opening_hours": {
      "open_now": true,
      "periods": [
        {
          "close": {
            "day": 0,
            "time": "2030"
          },
          "open": {
            "day": 0,
            "time": "0900"
          }
        }
      ],
      "weekday_text": [
        "Monday: 9:00 AM – 8:30 PM"
      ]
    },
    "photos": [
      {
        "photo_reference": "CmRaAAAA...",
        "height": 1152,
        "width": 1536
      }
    ],
    "editorial_summary": {
      "overview": "Iconic performing arts venue with distinctive shell-shaped design."
    },
    "business_status": "OPERATIONAL"
  },
  "status": "OK"
}
```

### Place Autocomplete Response
```json
{
  "predictions": [
    {
      "description": "Sydney Opera House, Bennelong Point, Sydney NSW, Australia",
      "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
      "reference": "ChIJN1t_tDeuEmsRUsoyG83frY4",
      "structured_formatting": {
        "main_text": "Sydney Opera House",
        "main_text_matched_substrings": [
          {
            "length": 6,
            "offset": 0
          }
        ],
        "secondary_text": "Bennelong Point, Sydney NSW, Australia"
      },
      "terms": [
        {
          "offset": 0,
          "value": "Sydney Opera House"
        },
        {
          "offset": 20,
          "value": "Bennelong Point"
        }
      ],
      "types": ["tourist_attraction", "point_of_interest", "establishment"]
    }
  ],
  "status": "OK"
}
```

---

## LocationIQ API Responses

### Geocoding Response
```json
[
  {
    "place_id": "234847916",
    "licence": "https://locationiq.com/attribution",
    "osm_type": "relation",
    "osm_id": "207359",
    "boundingbox": ["40.4774", "40.9162", "-74.2591", "-73.7004"],
    "lat": "40.7127753",
    "lon": "-74.0059728",
    "display_name": "New York City, New York, United States",
    "class": "place",
    "type": "city",
    "importance": 1.0182760007806,
    "icon": "https://locationiq.org/static/images/mapicons/poi_place_city.p.20.png",
    "address": {
      "city": "New York City",
      "state": "New York",
      "country": "United States",
      "country_code": "us"
    }
  }
]
```

### Autocomplete Response
```json
[
  {
    "place_id": "234847916",
    "licence": "https://locationiq.com/attribution",
    "osm_type": "relation",
    "osm_id": "207359",
    "lat": "40.7127753",
    "lon": "-74.0059728",
    "display_name": "New York City, New York, United States",
    "class": "place",
    "type": "city",
    "importance": 1.0182760007806,
    "address": {
      "city": "New York City",
      "state": "New York",
      "country": "United States",
      "country_code": "us"
    }
  }
]
```

### Places Search Response
```json
[
  {
    "place_id": "12345",
    "name": "Central Park",
    "description": "Large public park in Manhattan",
    "lat": 40.7829,
    "lng": -73.9654,
    "category": "park",
    "address": "New York, NY 10024, United States",
    "extratags": {
      "website": "https://www.centralparknyc.org/",
      "wikipedia": "en:Central Park"
    },
    "address_components": {
      "amenity": "park",
      "name": "Central Park"
    },
    "importance": 0.8,
    "place_type": "leisure",
    "class": "leisure"
  }
]
```

### Directions Response
```json
{
  "routes": [
    {
      "distance": 314200,
      "duration": 11340,
      "geometry": {
        "coordinates": [
          [-97.7437, 30.2672],
          [-96.7969, 32.7763]
        ]
      },
      "legs": [
        {
          "steps": [
            {
              "maneuver": {
                "instruction": "Head north on Congress Avenue",
                "type": "depart",
                "modifier": "straight"
              },
              "distance": 245,
              "duration": 30
            }
          ],
          "distance": 314200,
          "duration": 11340
        }
      ],
      "bbox": [-97.7437, 30.2672, -96.7969, 32.7763]
    }
  ]
}
```

---

## TripAdvisor Scraper Responses

### Restaurant Search Response
```json
{
  "restaurants": [
    {
      "name": "Platos Restaurant Bar",
      "address": "Calle Loíza, Isla Verde, Carolina, Puerto Rico",
      "location_id": "123456",
      "tripadvisor_url": "/Restaurant_Review-g147320-d123456-Reviews-Platos_Restaurant_Bar-Isla_Verde_Carolina.html",
      "coordinates": {
        "lat": null,
        "lng": null
      },
      "rating": null,
      "review_count": null,
      "price_level": null,
      "cuisine_types": []
    },
    {
      "name": "Piu Bello Gelato Restaurant",
      "address": "Ave. Isla Verde, Carolina, Puerto Rico",
      "location_id": "789012",
      "tripadvisor_url": "/Restaurant_Review-g147320-d789012-Reviews-Piu_Bello_Gelato_Restaurant-Carolina.html",
      "coordinates": {
        "lat": null,
        "lng": null
      }
    }
  ],
  "total_found": 28,
  "search_query": "restaurants Isla Verde",
  "timestamp": "2025-08-13T11:14:21Z"
}
```

### Attraction Search Response
```json
{
  "attractions": [
    {
      "name": "El Yunque National Forest",
      "address": "Route 191, Rio Grande, Puerto Rico",
      "location_id": "456789",
      "tripadvisor_url": "/Attraction_Review-g147320-d456789-Reviews-El_Yunque_National_Forest-Rio_Grande.html",
      "coordinates": {
        "lat": 18.3167,
        "lng": -65.75
      },
      "rating": 4.5,
      "review_count": 8420,
      "attraction_types": ["nature", "forest", "hiking"],
      "description": "Tropical rainforest with waterfalls and hiking trails"
    }
  ],
  "total_found": 15,
  "search_query": "attractions Puerto Rico",
  "timestamp": "2025-08-13T10:59:17Z"
}
```

### GraphQL Raw Response (Technical)
```json
{
  "data": [
    {
      "typeaheadSuggestions": {
        "results": [
          {
            "__typename": "Typeahead_LocationItem",
            "locationId": 123456,
            "title": "Platos Restaurant Bar",
            "secondaryText": "Carolina, Puerto Rico",
            "url": "/Restaurant_Review-g147320-d123456-Reviews-Platos_Restaurant_Bar-Isla_Verde_Carolina.html",
            "latitude": null,
            "longitude": null,
            "placeType": "restaurant"
          }
        ]
      }
    }
  ]
}
```

---

## Internal API Responses

### Explore Results Response
```json
{
  "success": true,
  "data": {
    "pois": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "placeId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
        "name": "Central Park",
        "address": "New York, NY 10024, United States",
        "rating": "4.4",
        "category": "attraction",
        "lat": 40.7829,
        "lng": -73.9654,
        "createdAt": "2025-08-13T10:30:00.000Z",
        "updatedAt": "2025-08-13T10:30:00.000Z",
        "imageUrl": "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=ABC123&key=...",
        "description": "Large public park in Manhattan • 4.4★ (15,234 reviews)",
        "isOpen": true,
        "priceLevel": null,
        "reviewCount": 15234
      }
    ],
    "location": "New York",
    "location_coords": {
      "lat": 40.7127753,
      "lng": -74.0059728
    },
    "maps_api_key": "AIzaSy...",
    "meta": {
      "total_pois": 20,
      "location": "New York",
      "maps_available": true
    }
  },
  "timestamp": "2025-08-13T21:17:21.631352Z",
  "_cache": {
    "status": "hit",
    "timestamp": "2025-08-13T21:17:21.631376Z",
    "backend": "Memory",
    "environment": "dev"
  }
}
```

### Route Results Response
```json
{
  "success": true,
  "data": {
    "route": {
      "distance": 314.2,
      "duration": 11340,
      "polyline": "encoded_polyline_string",
      "start": {
        "lat": 30.2672,
        "lng": -97.7437,
        "address": "Austin, TX"
      },
      "end": {
        "lat": 32.7763,
        "lng": -96.7969,
        "address": "Dallas, TX"
      }
    },
    "pois": [
      {
        "id": "poi_123",
        "name": "Roadside Diner",
        "category": "restaurant",
        "rating": "4.2",
        "distance_from_route": 0.5,
        "lat": 31.0,
        "lng": -97.0,
        "address": "Highway 35, Temple, TX"
      }
    ],
    "meta": {
      "total_pois": 15,
      "route_distance_km": 314.2,
      "estimated_drive_time": "3 hours 9 minutes"
    }
  }
}
```

### Places Search Response
```json
{
  "success": true,
  "data": {
    "places": [
      {
        "id": "place_456",
        "name": "Austin State Capitol",
        "formatted_address": "1100 Congress Ave, Austin, TX 78701",
        "lat": 30.2747,
        "lng": -97.7404,
        "place_types": ["tourist_attraction", "government"],
        "rating": 4.6,
        "reviews_count": 2841,
        "price_level": null,
        "phone_number": "(512) 463-0063",
        "website": "https://tspb.texas.gov/",
        "photos": [
          {
            "photo_reference": "CmRaAAAA...",
            "width": 4032,
            "height": 3024
          }
        ],
        "opening_hours": {
          "open_now": true,
          "periods": [...]
        }
      }
    ],
    "meta": {
      "total_results": 50,
      "query": "attractions Austin",
      "location": {
        "lat": 30.2672,
        "lng": -97.7437
      },
      "radius_km": 20
    }
  }
}
```

### Trip Details Response
```json
{
  "success": true,
  "data": {
    "trip": {
      "id": "trip_789",
      "name": "Austin Food Tour",
      "description": "Best BBQ and Tex-Mex in Austin",
      "start_date": "2025-09-01",
      "end_date": "2025-09-03",
      "route": {
        "waypoints": [
          {
            "lat": 30.2672,
            "lng": -97.7437,
            "address": "Downtown Austin",
            "order": 1
          }
        ],
        "total_distance_km": 45.2,
        "estimated_duration_hours": 8.5
      },
      "pois": [
        {
          "id": "poi_franklin",
          "name": "Franklin Barbecue",
          "category": "restaurant",
          "rating": "4.7",
          "visit_duration_minutes": 90,
          "notes": "Famous for brisket - arrive early!"
        }
      ],
      "created_at": "2025-08-13T10:00:00Z",
      "updated_at": "2025-08-13T15:30:00Z"
    }
  }
}
```

### Dashboard Response
```json
{
  "success": true,
  "data": {
    "trips": {
      "recent": [
        {
          "id": "trip_123",
          "name": "Weekend in San Antonio",
          "created_at": "2025-08-10T14:20:00Z",
          "poi_count": 8,
          "distance_km": 156.3
        }
      ],
      "count": 12
    },
    "suggested_interests": [
      {
        "id": 1,
        "name": "food_and_drink",
        "displayName": "Food & Drink",
        "isEnabled": true,
        "priority": 1
      }
    ],
    "stats": {
      "total_trips": 12,
      "total_pois": 147,
      "avg_trip_duration": "2.5 days"
    },
    "user": {
      "id": "user_456",
      "name": "John Doe",
      "email": "john@example.com"
    }
  }
}
```

### POI Clustering Response
```json
{
  "data": {
    "clusters": [
      {
        "id": "poi_27",
        "type": "single_poi",
        "lat": 18.31056,
        "lng": -65.79139,
        "count": 1,
        "pois": [
          {
            "id": 27,
            "name": "El Yunque National Forest",
            "category": "natural_feature",
            "lat": 18.31056,
            "lng": -65.79139,
            "rating": 4.8,
            "reviews_count": 5200,
            "formatted_address": "El Yunque, PR",
            "price_level": null
          }
        ],
        "zoom_level": 12,
        "generated_at": 1755466683
      },
      {
        "id": "cluster_3B6A6F1D4CB96DF754BC6C6EC2E4CFE4",
        "type": "cluster",
        "lat": 18.466945,
        "lng": -66.11028,
        "count": 2,
        "pois": [
          {
            "id": 10,
            "name": "Old San Juan",
            "category": "attraction",
            "lat": 18.46639,
            "lng": -66.11028,
            "rating": 4.8,
            "reviews_count": 1250,
            "formatted_address": "Old San Juan, San Juan, PR",
            "price_level": null
          },
          {
            "id": 11,
            "name": "San Juan National Historic Site",
            "category": "museum",
            "lat": 18.4675,
            "lng": -66.11028,
            "rating": 4.9,
            "reviews_count": 2100,
            "formatted_address": "San Juan, PR",
            "price_level": null
          }
        ],
        "type": "cluster",
        "avg_rating": 4.85,
        "category_breakdown": {
          "attraction": 1,
          "museum": 1
        },
        "zoom_level": 12,
        "generated_at": 1755466683
      }
    ],
    "viewport": {
      "north": 18.5,
      "south": 18.3,
      "east": -65.5,
      "west": -66.5
    },
    "zoom": 12,
    "filters": {},
    "cluster_count": 17,
    "poi_count": 19
  },
  "_cache": {
    "status": "hit",
    "timestamp": "2025-08-17T12:45:32.123Z",
    "backend": "ClusteringServer",
    "environment": "dev"
  }
}
```

---

## POI Clustering API Responses

### GET /api/pois/clusters

Real-time POI clustering endpoint optimized for map visualization. Returns clustered POIs based on viewport bounds and zoom level with intelligent caching via ETS.

**Query Parameters:**
- `north`, `south`, `east`, `west`: Viewport bounds (required)
- `zoom`: Zoom level 1-20 (optional, default: 12)
- `categories`: Comma-separated categories (optional)
- `min_rating`: Minimum rating filter (optional)

**Cluster Types:**
- `single_poi`: Individual POI marker
- `cluster`: Multiple POIs grouped together

**Performance Features:**
- Sub-5ms response times for cached results
- Concurrent processing with Task.async_stream
- Zoom-aware grid sizing for optimal clustering
- ETS-backed caching with 5-minute TTL

**Example Request:**
```
GET /api/pois/clusters?north=18.5&south=18.3&east=-65.5&west=-66.5&zoom=12
```

**Response Format:** (See POI Clustering Response above)

---

## Error Response Formats

### Standard Error Response
```json
{
  "success": false,
  "error": {
    "message": "Resource not found",
    "code": "NOT_FOUND",
    "details": ["Trip with ID 'invalid_id' does not exist"]
  },
  "timestamp": "2025-08-13T21:17:21.631352Z"
}
```

### Validation Error Response
```json
{
  "success": false,
  "error": {
    "message": "Validation failed",
    "code": "VALIDATION_ERROR",
    "details": [
      "Name can't be blank",
      "Email must be a valid email address",
      "Coordinates must be valid latitude/longitude"
    ]
  },
  "timestamp": "2025-08-13T21:17:21.631352Z"
}
```

### Authentication Error Response
```json
{
  "success": false,
  "error": {
    "message": "Authentication required",
    "code": "UNAUTHORIZED",
    "details": ["Valid JWT token required"]
  },
  "timestamp": "2025-08-13T21:17:21.631352Z"
}
```

### Rate Limit Error Response
```json
{
  "success": false,
  "error": {
    "message": "Rate limit exceeded",
    "code": "RATE_LIMITED",
    "details": ["API rate limit of 100 requests per minute exceeded"]
  },
  "timestamp": "2025-08-13T21:17:21.631352Z"
}
```

### External API Error Response
```json
{
  "success": false,
  "error": {
    "message": "External service unavailable",
    "code": "EXTERNAL_SERVICE_ERROR",
    "details": ["Google Places API returned 503 Service Unavailable"]
  },
  "timestamp": "2025-08-13T21:17:21.631352Z"
}
```

---

## Response Status Codes

| Code | Description | When Used |
|------|-------------|-----------|
| 200 | OK | Successful GET/PUT requests |
| 201 | Created | Successful POST requests |
| 204 | No Content | Successful DELETE requests |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Missing/invalid authentication |
| 403 | Forbidden | Valid auth but insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server errors |
| 502 | Bad Gateway | External service errors |
| 503 | Service Unavailable | Server maintenance/overload |

---

## Data Type Reference

### Common Field Types
- **ID Fields**: UUID format (`550e8400-e29b-41d4-a716-446655440000`)
- **Timestamps**: ISO 8601 format (`2025-08-13T21:17:21.631352Z`)
- **Coordinates**: Decimal degrees (`lat: 40.7829, lng: -73.9654`)
- **Ratings**: String format for display (`"4.4"`) or Decimal for calculations
- **Place Types**: Array of strings (`["restaurant", "food", "meal_takeaway"]`)
- **Distances**: Kilometers as float (`314.2`)
- **Durations**: Seconds as integer (`11340`) or human-readable (`"3 hours 9 minutes"`)

### Cache Metadata
Development environments include cache metadata:
```json
"_cache": {
  "status": "hit|miss|disabled",
  "timestamp": "2025-08-13T21:17:21.631376Z",
  "backend": "Memory|Redis|Disabled",
  "environment": "dev|prod|test"
}
```

---

## Response Size Guidelines

- **Small Response**: < 10KB (autocomplete, simple lookups)
- **Medium Response**: 10-100KB (place details, trip info)
- **Large Response**: 100KB-1MB (explore results, route with POIs)
- **Pagination**: Use for responses > 1MB or > 100 items

## Caching Strategy

- **Static Data**: 30 days (place details, cities)
- **Dynamic Data**: 15 minutes (search results, POIs)
- **User Data**: 5 minutes (trips, preferences)
- **Real-time Data**: No cache (live traffic, availability)