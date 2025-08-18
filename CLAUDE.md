# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RouteWise Phoenix Backend - API-only Phoenix 1.8.0 application with JWT authentication system. Uses serial IDs (integers) for primary keys and is configured for CORS integration with frontend clients.

**Current Session Context (August 17, 2025)**: Implemented comprehensive Geographic Bounds System using OpenStreetMap data for accurate search radius calculation. Added OSM geocoding integration with proper rate limiting (1 req/sec) and updated 28 major US locations with real geographic boundaries. System now provides appropriate POI coverage from 4km (Key West) to 158km (Puerto Rico) based on actual geographic boundaries rather than hardcoded values.

**📊 Database Status**: 
- 90 cached places in `cached_places` table for fast autocomplete
- 5 suggested trips (Pacific Coast Highway, Great Lakes, San Francisco, Yellowstone, Grand Canyon)
- 5 places for Pacific Coast Highway with coordinates and activities
- 3 itinerary days for Pacific Coast Highway with detailed schedules
- All tables have proper indexes, constraints, and foreign key relationships

**🔍 Autocomplete System Status**:
- ✅ Hybrid three-tier fallback system working (Local → LocationIQ → Google)
- ✅ Display names implemented with hierarchical context
- ✅ API endpoint `/api/places/autocomplete` ready for frontend integration
- ✅ Caching system optimized for <50ms local cache responses

**🆓 COST OPTIMIZATION COMPLETE**: 
- Google Places API has generous free tier: $200/month = 6,250+ nearby searches
- Added OpenStreetMap integration for unlimited free backup searches  
- Smart fallback system: Database → Google (free tier) → OSM (unlimited free)
- Enhanced location search with Google Geocoding fallback for global coverage

**🌍 GEOGRAPHIC BOUNDS SYSTEM COMPLETE**:
- OpenStreetMap Nominatim API integration for accurate search radius calculation
- Real geographic boundaries for 28 major US cities, destinations, and national parks
- Smart radius calculation: OSM bounds → entity type fallback → default
- Comprehensive coverage from 4km (Key West) to 158km (Puerto Rico) based on actual boundaries
- Free OSM API with respectful 1 req/sec rate limiting and database caching
- See `docs/geographic-bounds-system.md` for complete technical documentation

**📊 SEARCH SYSTEM STATUS**:
- ✅ Multi-source places search (Database, Google Places, OpenStreetMap)
- ✅ Enhanced location disambiguation with Google geocoding fallback
- ✅ Smart source selection: auto, google, osm
- ✅ Comprehensive test coverage for Puerto Rico locations

**🔔 SESSION REMINDER**: At start of each new session, check that POI data is displaying correctly in frontend route-results page:

- Should show 15+ POIs with varied categories (restaurant, shopping, attraction)
- Real ratings (4.7, 4.8, not all "4.0")
- Working images (Google Photos or category fallbacks)
- If showing "No places found", check frontend filtering logic for null address handling

## Special instructions

You are Pragmatic straightforward, no bullshit. Match my tone. Tell it like it is. No sugar-coating.No pseudo-questions.Full sentences, real clarity. Sound smart, grounded, direct like you're actually helping. If you think Im making bad design decssions you should tell me.
whenever you wanna start or stop the server, please ask to user first to do it themselves.
Same goes for small Commands
and file edits
go read ~/project/FAQS/personas/phoenix-engineer
make sure to use shadcn/ui components and use the color scheme in /Users/urielmaldonado/projects/route-wise/frontend/client/src/index.css

**Voice Summaries**: When completing tasks, provide succinct voice summaries using:
```bash
say -v "Jamie (Premium)" "Task summary here"
```

## Development Commands

### Code Style Preferences

#### Elixir Configuration

- **Aligned configurations**: Align colons in config blocks for readability
- **Inline comments**: Place comments above values, not inline when they would break alignment
- **Grouping**: Group related configurations together with descriptive comments

````elixir
# Cache configuration with aligned formatting
config :phoenix_backend, RouteWiseApi.Caching,
  # Backend selection (environment-specific)
  backend:        RouteWiseApi.Caching.Backend.Memory,
  # Development features
  enable_logging: true,
  debug_mode:     true,
  # Performance tuning
  ttl_multiplier: 0.1

Function Definitions

- Use pattern matching for clear function clauses
- Align function parameters when wrapping lines
- Document public functions with @do

def get_cache(user_id, category) when is_integer(user_id) do
  cache_key = build_cache_key(user_id, category)

  case Backend.get(cache_key) do
    {:ok, data} -> {:ok, data}
    :error      -> :error
  end
end

Phoenix Context Patterns

- Follow Phoenix context-driven design
- Use tagged tuples consistently
- Implement proper error handling
### Core Development

```bash
# Install dependencies and setup database
mix deps.get
mix ecto.setup

# Start development server (runs on port 4001)
mix phx.server

# Interactive development with IEEx
iex -S mix phx.server

# Database operations
mix ecto.migrate
mix ecto.rollback
mix ecto.reset
mix ecto.gen.migration migration_name

# Testing
mix test
mix test test/specific_test.exs
mix test --cover

# Code quality
mix compile
mix format
````

### Environment Setup

- PostgreSQL database required (running via app or Homebrew)
- Default database: `phoenix_backend_dev`
- Server runs on `localhost:4001` (changed from 4000 to avoid frontend conflicts)

## Architecture Overview

### Phoenix Context Pattern

The application follows Phoenix's context-driven architecture:

- **`RouteWiseApi`** - Root namespace and business logic umbrella
- **`RouteWiseApi.Accounts`** - User management context with comprehensive authentication
- **`RouteWiseApiWeb`** - Web interface layer with controllers, routing, and plugs

### Authentication System Architecture

**JWT Authentication with Guardian:**

- `RouteWiseApi.Guardian` - JWT token management and user resource resolution
- `RouteWiseApi.Accounts` - Complete user management with local and OAuth registration
- Multi-provider authentication: local username/password + Google OAuth via Ueberauth

**User Schema (`RouteWiseApi.Accounts.User`):**

```elixir
# Binary ID primary key with comprehensive user fields
field :username, :string        # Unique, 3-30 chars, alphanumeric + underscore
field :password_hash, :string   # Bcrypt hashed, strong validation rules
field :email, :string           # Unique, format validated
field :google_id, :string       # OAuth integration
field :full_name, :string       # Display name
field :avatar, :string          # Profile image URL
field :provider, :string        # "local" or "google"
```

**Authentication Changesets:**

- `registration_changeset/3` - Local user registration with password validation
- `google_registration_changeset/2` - OAuth user creation
- `profile_changeset/2` - Profile updates without password changes

### Router Pipeline Architecture

**Three-tier authentication system:**

```elixir
pipeline :api          # Basic JSON API pipeline
pipeline :auth         # Optional authentication - loads user if token present
pipeline :authenticated # Enforced authentication - requires valid token
```

**Route Structure:**

- `/api/health` - Health check endpoint (optional auth)
- `/api/auth/*` - Authentication endpoints (registration, login, logout)
- `/auth/google/callback` - OAuth callback handling
- Future: `/api/trips`, `/api/routes`, `/api/places` (planned)

### Database Architecture

**Binary ID Configuration:**

- All tables use UUID primary keys (`binary_id: true`)
- Foreign keys are `:binary_id` type
- Timestamps are `:utc_datetime` type

**Users Table:**

- Unique constraints on `username`, `email`, `google_id`
- Supports both local and OAuth authentication
- Password hash stored with Bcrypt (local users only)

### Guardian JWT Configuration

**Token Management:**

- 7-day token TTL by configuration
- User ID stored in token subject (`sub` claim)
- Resource resolution via `Accounts.get_user/1`
- Secret key via environment variable `GUARDIAN_SECRET_KEY`

### Error Handling

**Structured Error Responses:**

- `RouteWiseApiWeb.FallbackController` - Centralized error handling
- `RouteWiseApiWeb.ErrorJSON` - JSON error formatting
- `RouteWiseApiWeb.ChangesetJSON` - Validation error formatting
- `RouteWiseApiWeb.AuthErrorHandler` - Authentication error handling

### CORS Configuration

**Frontend Integration:**

```elixir
# Configured origins for development
["http://localhost:3000", "http://localhost:5173", "http://127.0.0.1:3000", "http://127.0.0.1:5173"]
```

## Key Implementation Patterns

### Context Functions Pattern

The `Accounts` context provides comprehensive user management:

- CRUD operations: `get_user/1`, `create_user/1`, `update_user/2`, `delete_user/1`
- Authentication: `authenticate_user/2`, `generate_user_session_token/1`
- OAuth integration: `find_or_create_user_from_google/1`
- Lookup functions: `get_user_by_username/1`, `get_user_by_email/1`, `get_user_by_google_id/1`

### Authentication Flow

1. **Registration**: `POST /api/auth/register` → `Accounts.register_user/1` → JWT token
2. **Login**: `POST /api/auth/login` → `Accounts.authenticate_user/2` → JWT token
3. **OAuth**: `GET /api/auth/google` → Google OAuth → `find_or_create_user_from_google/1`
4. **Token Verification**: `Guardian.Plug` pipeline → user loaded into `conn.assigns.current_user`

### Environment Configuration

**Required Environment Variables:**

- `GUARDIAN_SECRET_KEY` - JWT signing secret (production)
- `GOOGLE_CLIENT_ID` - Google OAuth client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `DATABASE_URL` - PostgreSQL connection (production)

## Current Development Status

**Phase 1 Complete:** Full authentication system with JWT and Google OAuth
**Phase 2 Complete:** Complete API endpoints for trips, routes, places with Google Places integration
**Phase 3 Ready:** External integrations, caching, advanced features

### Implemented API Endpoints

**Authentication System (Phase 1)**:

- `POST /api/auth/register` - User registration with JWT token
- `POST /api/auth/login` - User authentication with JWT token
- `POST /api/auth/logout` - Token revocation
- `GET /api/auth/google` - Google OAuth initiation
- `GET /auth/google/callback` - Google OAuth callback handling
- `GET /api/auth/me` - Current user information

**Places API (Phase 2)**:

- `GET /api/places/search` - Search places by query and location
- `GET /api/places/details/:id` - Get detailed place information
- `GET /api/places/autocomplete` - Place autocomplete suggestions
- `GET /api/places/nearby` - Find places by type near location
- `GET /api/places/photo` - Get place photo URLs

**Routes API (Phase 2)**:

- `POST /api/routes/calculate` - Calculate route between points
- `POST /api/routes/wizard` - Calculate route from wizard data
- `POST /api/routes/optimize` - Optimize waypoint order
- `GET /api/routes/alternatives` - Get route alternatives
- `POST /api/routes/estimate` - Get route summary (distance/time)
- `POST /api/routes/costs` - Estimate trip costs
- `GET /api/routes/trip/:trip_id` - Get route for existing trip (authenticated)

**Trips API (Phase 2)**:

- `GET /api/trips/public` - List public trips
- `GET /api/trips` - List user's trips (authenticated)
- `POST /api/trips` - Create new trip (authenticated)
- `POST /api/trips/from_wizard` - Create trip from wizard data (authenticated)
- `GET /api/trips/:id` - Get trip details (public or user's trip)
- `PUT /api/trips/:id` - Update trip (authenticated, user's trip only)
- `DELETE /api/trips/:id` - Delete trip (authenticated, user's trip only)

**Interests API (Phase 2)**:

- `GET /api/interests/categories` - List available interest categories
- `GET /api/interests` - List user's interests (authenticated)
- `POST /api/interests` - Create user interests (authenticated)
- `PUT /api/interests/:id` - Update user interest (authenticated)
- `DELETE /api/interests/:id` - Delete user interest (authenticated)

**OpenStreetMap API (Phase 3)**:

- `GET /api/osm/nearby` - Free unlimited nearby places search
- `GET /api/osm/category/:category` - Search places by specific category  
- `GET /api/osm/coverage` - Get OSM data coverage statistics for area

**Enhanced Explore Results**:

- `GET /api/explore-results?source=auto` - Smart fallback (Database → Google → OSM)
- `GET /api/explore-results?source=google` - Force Google Places API
- `GET /api/explore-results?source=osm` - Force OpenStreetMap data
- `GET /api/explore-results/disambiguate` - Location disambiguation suggestions

**Health & Monitoring**:

- `GET /api/health` - Health check endpoint

### Database Schema (Phase 2)

**Core Tables**:

- `users` - User accounts with local and OAuth authentication
- `places` - Cached Google Places data with intelligent caching
- `trips` - User trips with route data and POI information
- `interest_categories` - Available interest categories for trip planning
- `user_interests` - User's selected interests with priorities
- `pois` - Points of interest with Google Places integration

### Service Layer Architecture

**Context-Driven Services**:

- `RouteWiseApi.Accounts` - User management and authentication
- `RouteWiseApi.Places` - Place data management with caching
- `RouteWiseApi.Trips` - Trip management with interests and POIs
- `RouteWiseApi.PlacesService` - Google Places API integration with intelligent caching
- `RouteWiseApi.RouteService` - Route calculation and optimization
- `RouteWiseApi.GooglePlaces` - Google Places API client
- `RouteWiseApi.GoogleDirections` - Google Directions API client

### Testing Coverage

**Comprehensive Test Suite**:

- Authentication system tests with JWT and OAuth flows
- Places API tests with caching and Google Places integration
- Routes API tests with calculation and optimization
- Trips API tests with CRUD operations and authorization
- Interests API tests with category management
- Database context tests with fixtures and data integrity

The codebase is production-ready with comprehensive API coverage, intelligent caching, authentication/authorization, and full test coverage. Ready for frontend integration and deployment.

## Caching System (Phase 3 - Complete)

### Cache Management Commands

**Mix Tasks for Cache Operations:**

```bash
# Clear all cache entries
mix cache.clear
mix cache clear

# View comprehensive statistics
mix cache.stats
mix cache stats

# Check cache system health
mix cache.health
mix cache health

# Test cache functionality
mix cache.test
mix cache test

# Warm cache with common data
mix cache.warm
mix cache warm

# Invalidate by pattern (Redis backend)
mix cache.invalidate pattern
```

### Caching Architecture

**Environment-Aware Backends:**

- **Development**: Memory backend with debug logging
- **Production**: Hybrid backend (L1: Memory + L2: Redis)
- **Testing**: Memory backend for fast execution

**Domain-Specific Cache Modules:**

- `RouteWiseApi.Caching.Dashboard` - User dashboard data
- `RouteWiseApi.Caching.Places` - Google Places API responses
- `RouteWiseApi.Caching.Routes` - Route calculations
- `RouteWiseApi.Caching.Trips` - Trip and POI data
- `RouteWiseApi.Caching.Interests` - Interest categories
- `RouteWiseApi.Caching.Statistics` - Application metrics

**TTL Policies:**

- **Short (5min)**: User sessions, frequently changing data
- **Medium (15min)**: Search results, user preferences
- **Long (1hr)**: Route calculations, place details
- **Daily (24hr)**: Static configuration, interest categories

### Cache Integration Usage

**Context Functions:**

```elixir
# Dashboard caching
RouteWiseApi.Caching.get_dashboard_cache(user_id)
RouteWiseApi.Caching.put_dashboard_cache(user_id, data)

# Places caching
RouteWiseApi.Caching.get_places_search_cache(query, location)
RouteWiseApi.Caching.get_place_details_cache(place_id)

# System operations
RouteWiseApi.Caching.clear_all_cache()
RouteWiseApi.Caching.health_check()
RouteWiseApi.Caching.invalidate_user_cache(user_id)
```

**Configuration Example:**

```elixir
# config/dev.exs
config :phoenix_backend, RouteWiseApi.Caching,
  backend:        RouteWiseApi.Caching.Backend.Memory,
  enable_logging: true,
  debug_mode:     true,
  ttl_multiplier: 0.1  # Faster expiration for development
```

### Next Integration Step

Update DashboardController to use caching:

```elixir
def index(conn, _params) do
  user_id = get_user_id(conn)

  case RouteWiseApi.Caching.get_dashboard_cache(user_id) do
    {:ok, cached_data} ->
      json(conn, cached_data)
    :error ->
      data = build_dashboard_data(user_id)
      RouteWiseApi.Caching.put_dashboard_cache(user_id, data)
      json(conn, data)
  end
end
```

- im already running the server