# RouteWise API

Phoenix backend API for the RouteWise application.

## Getting Started

### Prerequisites
- Elixir 1.14+
- Phoenix 1.7.21
- PostgreSQL 14+

### Installation

1. Install dependencies:
   ```bash
   mix deps.get
   ```

2. Create and setup the database:
   ```bash
   mix ecto.setup
   ```

3. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

The API will be available at [`localhost:4001`](http://localhost:4001).

### API Endpoints

#### Health Check
- **GET** `/api/health` - Returns API health status

#### Authentication
- **POST** `/api/auth/register` - User registration with JWT token
- **POST** `/api/auth/login` - User authentication with JWT token
- **POST** `/api/auth/logout` - Token revocation
- **GET** `/api/auth/google` - Google OAuth initiation
- **GET** `/auth/google/callback` - Google OAuth callback handling
- **GET** `/api/auth/me` - Current user information

#### Places & Search (NEW - Hybrid System)
- **GET** `/api/places/autocomplete` - Hybrid autocomplete (Local Cache → LocationIQ → Google Places)
- **GET** `/api/explore-results` - Find POIs around any location with smart fallback
- **GET** `/api/places/search` - Search places by query and location
- **GET** `/api/places/details/:id` - Get detailed place information
- **GET** `/api/places/nearby` - Find places by type near location
- **GET** `/api/places/photo` - Get place photo URLs

#### OpenStreetMap Integration (FREE Alternative)
- **GET** `/api/osm/nearby` - Free unlimited nearby places search
- **GET** `/api/osm/category/:category` - Search places by specific category
- **GET** `/api/osm/coverage` - Get OSM data coverage statistics for area

#### Routes & Navigation
- **POST** `/api/routes/calculate` - Calculate route between points
- **POST** `/api/routes/wizard` - Calculate route from wizard data
- **POST** `/api/routes/optimize` - Optimize waypoint order
- **GET** `/api/routes/alternatives` - Get route alternatives
- **POST** `/api/routes/estimate` - Get route summary (distance/time)
- **POST** `/api/routes/costs` - Estimate trip costs
- **GET** `/api/routes/trip/:trip_id` - Get route for existing trip (authenticated)

#### Trips Management
- **GET** `/api/trips/public` - List public trips
- **GET** `/api/trips` - List user's trips (authenticated)
- **POST** `/api/trips` - Create new trip (authenticated)
- **POST** `/api/trips/from_wizard` - Create trip from wizard data (authenticated)
- **GET** `/api/trips/:id` - Get trip details (public or user's trip)
- **PUT** `/api/trips/:id` - Update trip (authenticated, user's trip only)
- **DELETE** `/api/trips/:id` - Delete trip (authenticated, user's trip only)

#### User Interests
- **GET** `/api/interests/categories` - List available interest categories
- **GET** `/api/interests` - List user's interests (authenticated)
- **POST** `/api/interests` - Create user interests (authenticated)
- **PUT** `/api/interests/:id` - Update user interest (authenticated)
- **DELETE** `/api/interests/:id` - Delete user interest (authenticated)

### Configuration

#### CORS
The API is configured to accept requests from:
- `http://localhost:3000`
- `http://localhost:5173`
- `http://127.0.0.1:3000`
- `http://127.0.0.1:5173`

#### Database
- Development: `phoenix_backend_dev`
- Default PostgreSQL connection on `localhost:5432`

### Development

#### Useful Commands
```bash
# Run tests
mix test

# Run with interactive shell
iex -S mix phx.server

# Reset database
mix ecto.reset

# Generate new migration
mix ecto.gen.migration migration_name
```

#### Code Organization
```
lib/
├── phoenix_backend/          # Business logic & contexts
├── phoenix_backend_web/      # Web interface (controllers, views, etc.)
│   ├── controllers/
│   └── router.ex
├── mix.exs                   # Dependencies & project config
└── config/                   # Environment configurations
```

### Production

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
