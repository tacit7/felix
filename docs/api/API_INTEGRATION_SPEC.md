# RouteWise Backend API Integration Specification

## Overview
Unified API specification for RouteWise backend services, covering both Phoenix and Express.js implementations.

## Base URLs
- **Phoenix Backend**: `http://localhost:4001/api`
- **Express.js Frontend Server**: `http://localhost:3001/api`

## Authentication
- **Method**: JWT tokens via Authorization header or auth_token cookie
- **Format**: `Authorization: Bearer <token>`
- **Consistency**: Both systems use same JWT validation logic

## Response Format Standards

### Success Response
```json
{
  "success": true,
  "data": <payload>,
  "timestamp": "2024-08-05T10:30:00.000Z"
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "message": "Human-readable error description",
    "code": "ERROR_CODE",
    "details": ["specific error 1", "specific error 2"]
  },
  "timestamp": "2024-08-05T10:30:00.000Z"
}
```

## Endpoint Mapping

### Authentication (Phoenix Primary)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/auth/register` | POST | User registration with JWT token | No |
| `/auth/login` | POST | User authentication with JWT token | No |
| `/auth/logout` | POST | Token revocation | Yes |
| `/auth/google` | GET | Google OAuth initiation | No |
| `/auth/google/callback` | GET | Google OAuth callback handling | No |
| `/auth/me` | GET | Current user information | Yes |

### Places & Search (Phoenix Primary - NEW Hybrid System)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/places/autocomplete` | GET | Hybrid autocomplete (Local Cache → LocationIQ → Google) | No |
| `/explore-results` | GET | Find POIs around any location with smart fallback | No |
| `/places/search` | GET | Search places by query and location | No |
| `/places/details/{id}` | GET | Get detailed place information | No |
| `/places/nearby` | GET | Find places by type near location | No |
| `/places/photo` | GET | Get place photo URLs | No |

### OpenStreetMap Integration (Phoenix Primary - FREE Alternative)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/osm/nearby` | GET | Free unlimited nearby places search | No |
| `/osm/category/{category}` | GET | Search places by specific category | No |
| `/osm/coverage` | GET | Get OSM data coverage statistics for area | No |

### Routes & Navigation (Phoenix Primary)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/routes/calculate` | POST | Calculate route between points | No |
| `/routes/wizard` | POST | Calculate route from wizard data | No |
| `/routes/optimize` | POST | Optimize waypoint order | No |
| `/routes/alternatives` | GET | Get route alternatives | No |
| `/routes/estimate` | POST | Get route summary (distance/time) | No |
| `/routes/costs` | POST | Estimate trip costs | No |
| `/routes/trip/{trip_id}` | GET | Get route for existing trip | Yes |

### Trips Management (Phoenix Primary)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/trips/public` | GET | List public trips | No |
| `/trips` | GET | List user's trips | Yes |
| `/trips` | POST | Create new trip | Yes |
| `/trips/from_wizard` | POST | Create trip from wizard data | Yes |
| `/trips/{id}` | GET | Get trip details (public or user's trip) | Optional |
| `/trips/{id}` | PUT | Update trip (user's trip only) | Yes |
| `/trips/{id}` | DELETE | Delete trip (user's trip only) | Yes |

### User Interests (Phoenix Primary)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/interests/categories` | GET | List available interest categories | No |
| `/interests` | GET | List user's interests | Yes |
| `/interests` | POST | Create user interests | Yes |
| `/interests/{id}` | PUT | Update user interest | Yes |
| `/interests/{id}` | DELETE | Delete user interest | Yes |

### Dashboard Aggregation (Phoenix Primary)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/dashboard` | GET | Aggregated dashboard data | Optional |

### Health & Monitoring (Phoenix Primary)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/health` | GET | Health check endpoint | No |

## Data Type Definitions

### Interest Category
```typescript
interface InterestCategory {
  id: number;
  name: string;
  displayName: string;
  description: string | null;
  iconName: string | null;
  isActive: boolean;
  createdAt: string;
}
```

### User Interest
```typescript
interface UserInterest {
  id: number;
  userId: number;
  categoryId: number;
  isEnabled: boolean;
  priority: number;
  createdAt: string;
  updatedAt: string;
  category: InterestCategory;
}
```

### Dashboard Data
```typescript
interface DashboardData {
  trips: {
    recent: Trip[];
    count: number;
  };
  suggested_interests: UserInterest[];
  categories: InterestCategory[];
  user: {
    id: number;
    name: string;
    email: string;
  } | null;
  stats: {
    total_trips: number;
    total_pois: number;
    avg_trip_duration: string;
  };
}
```

## Integration Patterns

### Phoenix → Express.js Communication
- **Method**: HTTP client with connection pooling
- **Timeout**: 5 seconds with exponential backoff
- **Caching**: Cache Express.js responses for 15 minutes
- **Fallback**: Return basic data if Express.js unavailable

### Error Handling
- **Network Errors**: Return graceful fallback data
- **Authentication Errors**: Propagate 401/403 to frontend
- **Validation Errors**: Return detailed field-level errors

## Performance Requirements
- **Response Time**: < 200ms for all endpoints
- **Availability**: 99.9% uptime target
- **Caching**: Aggressive caching with smart invalidation
- **Rate Limiting**: 100 req/min per user for dashboard, 10 req/5min for suggestions

## Monitoring & Observability
- **Logs**: Structured JSON logs with correlation IDs
- **Metrics**: Response times, error rates, cache hit ratios
- **Tracing**: Distributed tracing across service boundaries
- **Health Checks**: `/health` endpoint for both services

## Migration Strategy
1. **Phase 1**: Implement unified response formats
2. **Phase 2**: Add Phoenix → Express.js integration layer
3. **Phase 3**: Frontend updates to use standardized responses
4. **Phase 4**: Performance optimization and monitoring

## Version Compatibility
- **Current**: v1.0 (baseline implementations)
- **Target**: v1.1 (unified integration)
- **Backward Compatibility**: Maintain existing endpoint contracts