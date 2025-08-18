# CLAUDE_CONTEXT.md

This file provides context to future Claude Code instances about the current state and session history for the RouteWise Phoenix Backend project.

## Current Project State (August 5, 2025)

### Project Overview
RouteWise Phoenix Backend - API-only Phoenix 1.8.0 application serving as the backend for a travel planning application. Features comprehensive JWT authentication, Google Places API integration, complete trip management system, and Google Directions API for route calculation.

### Development Phase Status
- ✅ **Phase 1 Complete**: Core Infrastructure & Authentication System + ID Migration
- ✅ **Phase 2 Complete**: Google Places API Integration  
- ✅ **Phase 3 Complete**: Trip Management System & Route Calculation
- ✅ **Phase 4 Complete**: Frontend Integration Testing & Communication Setup
- ✅ **Phase 5 Complete**: Google OAuth & POI API Implementation
- ✅ **Phase 6 Complete**: Frontend OAuth Integration & MCP Debugging
- ✅ **Phase 7 Complete**: Backend API Integration Architecture
- 🔄 **Phase 8 Next**: Production Deployment & Advanced Features

### Key Architectural Decisions Made

#### Authentication Architecture
- **JWT with Guardian**: 7-day token TTL, user ID in subject claim (Updated for integer IDs)
- **Multi-provider Auth**: Local username/password + Google OAuth with Ueberauth
- **Three-tier Router Pipelines**: `:api` (basic), `:auth` (optional), `:authenticated` (required)
- **Serial IDs**: All tables migrated from binary_id to serial IDs for frontend compatibility

#### Places API Integration Architecture  
- **Cache-First Strategy**: 24-hour TTL with transparent refresh of stale data
- **Geographic Database**: Decimal precision coordinates with strategic indexes
- **Full API Coverage**: Text search, nearby, details, autocomplete, photos
- **Production-Ready**: Comprehensive error handling, validation, and logging

#### Database Design Patterns
- **Serial ID Primary Keys**: Migrated from UUID to integer IDs for frontend compatibility
- **Geographic Indexing**: Compound indexes on lat/lng for performance
- **Array and Map Fields**: Efficient storage of complex Google Places data and route data
- **Timestamp Tracking**: UTC datetime with automatic cache expiration
- **Trip Management Schema**: Complete system with trips, pois, interest_categories, user_interests

### Current File Structure
```
lib/phoenix_backend/
├── integrations/                      # Backend integration layer (NEW)
│   └── express_client.ex              # HTTP client for Express.js communication (NEW)
├── cache.ex                           # In-memory TTL cache service (NEW)
├── accounts.ex & accounts/user.ex     # User management context (migrated to serial ID)
├── guardian.ex                        # JWT token management (updated for integer IDs)
├── places.ex & places/place.ex        # Places context with caching (migrated to serial ID)
├── trips.ex                           # Trip management context
├── trips/                             # Trip-related schemas
│   ├── trip.ex                        # Trip schema
│   ├── poi.ex                         # Point of Interest schema
│   ├── interest_category.ex           # Interest category schema
│   └── user_interest.ex               # User interest schema
├── google_places.ex                   # Google Places API client
├── google_directions.ex               # Google Directions API client
├── places_service.ex                  # Service layer with caching logic
├── route_service.ex                   # Route calculation service
└── phoenix_backend_web/
    ├── controllers/
    │   ├── auth_controller.ex          # Authentication endpoints
    │   ├── places_controller.ex        # 5 Places API endpoints
    │   ├── trips_controller.ex         # Trip management endpoints
    │   ├── routes_controller.ex        # Route calculation endpoints
    │   ├── dashboard_controller.ex     # Enhanced with Express.js integration (UPDATED)
    │   ├── monitoring_controller.ex    # Performance monitoring endpoints (NEW)
    │   ├── trips_json.ex               # Trip JSON formatting
    │   └── fallback_controller.ex      # Enhanced error handling
    ├── plugs/
    │   └── unified_auth.ex             # Cross-system authentication plug (NEW)
    └── router.ex                       # Updated with monitoring endpoints
```

### Environment Configuration
```bash
# Required environment variables
GUARDIAN_SECRET_KEY="jwt-signing-secret"
GOOGLE_CLIENT_ID="oauth-client-id" 
GOOGLE_CLIENT_SECRET="oauth-client-secret"
GOOGLE_PLACES_API_KEY="google-places-api-key"        # Added in Phase 2
GOOGLE_DIRECTIONS_API_KEY="google-directions-api-key" # Added in Phase 3
```

### API Endpoints Available
#### Authentication (Phase 1)
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login  
- `GET /api/auth/me` - Current user info
- `GET /api/auth/google` - Google OAuth flow

#### Places (Phase 2) 
- `GET /api/places/search` - Text search with location and filters
- `GET /api/places/details/:id` - Detailed place information
- `GET /api/places/autocomplete` - Place name autocomplete  
- `GET /api/places/nearby` - Find places by type near location
- `GET /api/places/photo` - Get photo URLs with size options

#### Trip Management (Phase 3)
- `GET /api/trips` - List user trips
- `POST /api/trips` - Create new trip
- `GET /api/trips/:id` - Get trip details
- `PUT /api/trips/:id` - Update trip
- `DELETE /api/trips/:id` - Delete trip
- `POST /api/trips/from-wizard` - Create trip from frontend wizard data

#### Route Calculation (Phase 3)
- `POST /api/routes/calculate` - Calculate route between points
- `POST /api/routes/optimize` - Optimize waypoint order

#### Backend Integration & Monitoring (Phase 7)
- `GET /api/dashboard` - Enhanced dashboard with Express.js user interests integration
- `GET /api/monitoring/health` - Overall system health with Express.js, cache, and database status
- `GET /api/monitoring/express` - Detailed Express.js integration metrics and connectivity tests
- `GET /api/monitoring/cache` - Cache performance metrics with efficiency calculations

### Recent Implementation Patterns

#### ID Migration Pattern (Phase 1 & 3)
```elixir
# Table recreation strategy for ID type changes
def up do
  create table(:users_new) do
    add :username, :string, null: false
    # ... other fields
    timestamps(type: :utc_datetime)
  end
  
  execute "INSERT INTO users_new (username, ...) SELECT username, ... FROM users"
  drop table(:users)
  rename table(:users_new), to: table(:users)
end

# Schema update for serial IDs
@primary_key {:id, :id, autogenerate: true}
@foreign_key_type :id
```

#### Guardian JWT Integer ID Pattern
```elixir
# Updated Guardian for integer ID handling
def resource_from_claims(%{"sub" => id}) do
  case Integer.parse(id) do
    {int_id, ""} ->
      case Accounts.get_user(int_id) do
        nil -> {:error, :resource_not_found}
        user -> {:ok, user}
      end
    _ ->
      {:error, :invalid_id_format}
  end
end
```

#### Error Handling Pattern
```elixir
# Custom validation errors in controllers
{:error, {:bad_request, message}} 

# FallbackController handles with proper HTTP status
def call(conn, {:error, {:bad_request, message}}) do
  conn |> put_status(:bad_request) |> render(:"400", %{errors: %{detail: message}})
end
```

#### Geographic Query Pattern
```elixir
# Efficient bounding box queries for location search
lat_delta = radius / 111_320  # meters per degree latitude
lng_delta = radius / (111_320 * :math.cos(location.lat * :math.pi() / 180))

query
|> where([p], p.latitude >= ^(location.lat - lat_delta))
|> where([p], p.latitude <= ^(location.lat + lat_delta))
|> order_by([p], desc: p.rating, desc: p.reviews_count)
```

#### Trip Management Pattern (Phase 3)
```elixir
# Trip creation from frontend wizard data
def create_trip_from_wizard(wizard_data, user_id) do
  attrs = Trip.from_wizard_data(wizard_data, user_id)
  create_trip(attrs)
end

# Trip with automatic route calculation
def create_from_wizard(conn, %{"wizard_data" => wizard_data} = params) do
  current_user = Guardian.Plug.current_resource(conn)
  calculate_route = Map.get(params, "calculate_route", true)

  with {:ok, %Trip{} = trip} <- Trips.create_trip_from_wizard(wizard_data, current_user.id),
       {:ok, updated_trip} <- maybe_calculate_route(trip, wizard_data, calculate_route) do
    render(conn, :show, trip: updated_trip)
  end
end
```

#### Route Calculation Pattern (Phase 3)
```elixir
# Google Directions API integration
def calculate_route(origin, destination, waypoints \\ [], options \\ %{}) do
  params = build_request_params(origin, destination, waypoints, options)
  
  case make_request(params) do
    {:ok, response} -> parse_directions_response(response)
    {:error, reason} -> {:error, reason}
  end
end

# Route data formatting for frontend
defp format_route_data(route) do
  %{
    distance: leg["distance"]["text"],
    duration: leg["duration"]["text"],
    polyline: route["overview_polyline"]["points"],
    legs: format_legs(route["legs"]),
    route_points: decode_polyline(route["overview_polyline"]["points"]),
    bounds: route["bounds"],
    warnings: route["warnings"] || []
  }
end
```

#### Caching Service Pattern
```elixir
# Cache-first with automatic refresh
def get_place_details(google_place_id) do
  case Places.get_place_by_google_id(google_place_id) do
    %Place{} = place ->
      if Place.cache_fresh?(place, @cache_ttl_hours) do
        {:ok, place}  # Return cached
      else
        refresh_place_details(place)  # Refresh stale cache
      end
    nil ->
      fetch_and_cache_place_details(google_place_id)  # Fetch new
  end
end
```

### Testing Strategy Established
- **Context Tests**: Full CRUD operations and business logic
- **Controller Tests**: API endpoint validation and error handling
- **Integration Approach**: Test fixtures for consistent data
- **Geographic Testing**: Location-based queries with realistic coordinates

### Known Technical Patterns

#### Ecto Query Best Practices
- Use pipe syntax for complex queries with bindings: `query |> where([p], condition)`
- Avoid inline order_by in from clauses: causes compilation errors
- Use `from()` with parentheses for multi-line queries

#### Elixir Error Handling
- Rescue clauses: `e in ExceptionType ->` not `ExceptionType = e ->`
- Logger methods: Use `Logger.warning/2` not deprecated `Logger.warn/1`
- Function clause patterns: Ensure all expected tuple formats handled

### Development Environment Notes
- **Server Port**: 4001 (avoiding frontend conflicts on 4000)
- **Database**: PostgreSQL via app (not Homebrew services)
- **CORS**: Configured for localhost:3000, 5173 (frontend dev servers)
- **Testing**: All tests passing, no compiler warnings

### Future Development Guidelines

#### Next Phase Recommendations
1. **Frontend Integration**: Test API compatibility with frontend schemas
2. **API Key Configuration**: Set up production Google API keys
3. **Route Caching**: Consider caching route calculations for performance
4. **Enhanced Features**: Add traffic data, route alternatives, and optimization

#### Architectural Consistency
- Maintain serial ID usage across all tables (migrated from binary_id)
- Follow established Context -> Service -> Controller pattern
- Use strategic database indexing for performance
- Implement comprehensive parameter validation
- Include complete test coverage for new features
- Preserve data integrity during migrations with table recreation strategy

### Session History Summary

#### Latest Session (August 5, 2025 - Backend API Integration Architecture)
**Focus**: Production-ready backend integration architecture connecting Phoenix and Express.js systems
**Achievements**: 
- Implemented ExpressClient with HTTP communication, retry logic, and 15-minute TTL caching ✅
- Created Cache service with TTL management and automatic cleanup ✅
- Built UnifiedAuth plug for cross-system JWT authentication (Phoenix Guardian + Express.js tokens) ✅
- Developed MonitoringController with real-time health, Express.js metrics, and cache performance endpoints ✅
- Enhanced DashboardController with Express.js integration and smart fallback to Phoenix data ✅
- Successfully tested live Phoenix-Express.js communication with 100% connectivity ✅
- Fixed compilation errors: Float.round type issues, json/2 import, tuple encoding ✅
- Created comprehensive backend integration architecture documentation ✅
- Updated FAQ with 5 new backend integration and debugging entries ✅

#### Previous Session (August 5, 2025 - OAuth Frontend Fix & MCP Sequential Thinking)
**Focus**: Final OAuth integration resolution using MCP Sequential Thinking for systematic debugging
**Achievements**: 
- Resolved Google OAuth frontend URL resolution issue causing 404s ✅
- Successfully used MCP Sequential Thinking for systematic 8-step debugging process ✅
- Fixed Phoenix log file binary format issue with proper logger_file_backend configuration ✅
- Created AuthSuccess and AuthError pages for complete OAuth flow handling ✅
- Completed end-to-end Google OAuth authentication from frontend to backend ✅
- Clarified Phoenix development workflow and hot reloading requirements ✅
- All frontend-backend integration issues now resolved ✅
- Updated FAQ with 5 new OAuth debugging and MCP usage entries ✅

#### Previous Session (August 5, 2025 - Integration Testing & Google OAuth Debugging)
**Focus**: Comprehensive API integration testing and critical Google OAuth environment resolution
**Achievements**: 
- Created comprehensive integration test script covering all 9 API endpoints ✅
- Resolved Google OAuth 404 errors by fixing Phoenix environment variable loading ✅
- Implemented complete missing POI API with controller, routes, and JSON views ✅
- Fixed Google Directions API environment variable configuration issues ✅
- Created Postman collection for systematic OAuth flow testing ✅
- Configured Phoenix file logging system for debugging integration issues ✅
- Verified all APIs working and ready for frontend integration ✅
- Updated FAQ with 6 critical integration and OAuth debugging entries ✅

#### Previous Session (August 5, 2025 - Authentication Integration & Debugging)
**Focus**: Critical JWT cookie authentication bug resolution and frontend integration setup
**Achievements**: 
- Fixed 401 authentication errors preventing frontend integration ✅
- Resolved Guardian.Plug.VerifyCookie deprecation issues ✅
- Created custom AuthPlug.verify_cookie_token/2 for HTTP-only cookie support ✅
- Established proper .env file with GUARDIAN_SECRET_KEY and security configuration ✅
- Updated React frontend User interface and auth context for Phoenix compatibility ✅
- Added CORS support for localhost:3001 frontend integration ✅
- Confirmed both Bearer token and cookie authentication fully functional ✅
- Updated FAQ with 6 critical authentication debugging entries ✅

#### Previous Session (August 5, 2025 - Frontend Integration Testing)
**Focus**: Comprehensive frontend integration testing and communication setup
**Achievements**: 
- Tested all authentication endpoints (registration, login, JWT validation) ✅
- Verified trip management APIs with correct wizard data format ✅
- Confirmed external APIs (Places, Routes) fail gracefully without API keys ✅
- Validated all responses use integer IDs matching frontend TypeScript schema ✅
- Created FRONTEND_BACKEND_CHAT.md for ongoing frontend-backend collaboration ✅
- Updated FAQ with 7 new integration-specific entries ✅
- Established manual trigger communication system for AI coordination ✅

#### Previous Session (August 4, 2025 - Resumed Session)
**Focus**: Complete backend transformation with ID migration, trip management, and route calculation
**Achievements**: 
- Migrated all tables from binary_id to serial IDs for frontend compatibility
- Updated Guardian JWT system for integer user IDs  
- Implemented complete trip management system (4 new tables)
- Created Google Directions API integration with route calculation
- Added comprehensive trip and route API endpoints
- Enhanced documentation with 5 new FAQ entries

#### Previous Sessions
- **August 4, 2025 (Morning)**: Environment initialization, compiler cleanup
- **August 3, 2025**: Authentication system implementation (Phase 1)
- **Previous**: Initial Phoenix setup with CORS and health endpoints

---

## Context for Future Claude Instances

### When Resuming Development
1. **Check STATUS.md** for latest progress and next steps
2. **Review CLAUDE.md** for architectural patterns and commands
3. **Examine FAQ.md** for solutions to common issues encountered
4. **Verify Environment**: Ensure database running and dependencies updated

### For Debugging Issues
1. **Compiler Errors**: Check FAQ.md for Ecto query syntax and error handling patterns
2. **Test Failures**: Review test fixtures and established testing patterns  
3. **API Issues**: Verify FallbackController error handling coverage
4. **Database Issues**: Check migration status and index performance

### For Adding New Features
1. **Follow Established Patterns**: Context -> Service -> Controller -> Tests
2. **Maintain Consistency**: Serial IDs, UTC timestamps, comprehensive validation
3. **Consider Caching**: Follow Places caching patterns for similar data
4. **Update Documentation**: FAQ entries for new patterns and solutions
5. **Frontend Compatibility**: Ensure new APIs match frontend schema expectations

---

### Critical Authentication Integration Patterns (Added August 5, 2025)

#### Custom Guardian Cookie Authentication
```elixir
# Created custom AuthPlug for HTTP-only cookie support
defmodule RouteWiseApiWeb.Plugs.AuthPlug do
  def verify_cookie_token(conn, _opts) do
    with token when is_binary(token) <- get_token_from_cookie(conn),
         {:ok, claims} <- RouteWiseApi.Guardian.decode_and_verify(token),
         {:ok, user} <- RouteWiseApi.Guardian.resource_from_claims(claims) do
      conn
      |> Guardian.Plug.put_current_token(token)
      |> Guardian.Plug.put_current_claims(claims)
      |> Guardian.Plug.put_current_resource(user)
    else
      _error -> conn
    end
  end
  
  defp get_token_from_cookie(conn) do
    case conn.req_cookies do
      %{"auth_token" => token} -> token
      _ -> nil
    end
  end
end
```

#### Router Pipeline Configuration for Dual Authentication
```elixir
# Updated router pipelines for both Bearer and cookie auth
pipeline :auth do
  plug :accepts, ["json"]
  plug :fetch_cookies
  plug Guardian.Plug.Pipeline, module: RouteWiseApi.Guardian
  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug RouteWiseApiWeb.Plugs.AuthPlug, :verify_cookie_token
  plug Guardian.Plug.LoadResource, allow_blank: true
end
```

#### Environment Configuration Requirements
```bash
# .env file (created for persistent environment variables)
GUARDIAN_SECRET_KEY=f7d9c2e1a5b8f6e3d2c4a7b9f1e8d6c3a2b5f9e7d1c8a4b6f3e2d9c7a1b4f8e6d5c2a9b7f4e1d8c6a3b2f5e9d7c1a4b8f6e3d2c9a7b1f4e8d6c5a2b9f7
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_PLACES_API_KEY=your_google_places_api_key
FRONTEND_URL=http://localhost:3001

# .gitignore additions for security
.env
.env.local
.env.production
.env.test
cookies*.txt
```

#### Frontend Integration Updates
```typescript
// Updated React User interface for Phoenix compatibility
interface User {
  id: string; // Phoenix uses string UUIDs converted from integers
  username: string;
  email: string;
  full_name?: string;  // Added Phoenix fields
  avatar?: string;     // Added Phoenix fields
  provider: string;    // Added Phoenix fields
  created_at: string;  // Added Phoenix fields
}
```

---

*Context Last Updated: August 5, 2025 - Backend API Integration Architecture Complete*  
*Next Recommended Focus: Production Deployment & Advanced RouteWise Features*