# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :phoenix_backend,
  namespace: RouteWiseApi,
  ecto_repos: [RouteWiseApi.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :phoenix_backend, RouteWiseApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: RouteWiseApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RouteWiseApi.PubSub,
  live_view: [signing_salt: "ADaM2gFS"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :phoenix_backend, RouteWiseApi.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :phoenix_backend, RouteWiseApi.Caching,
  default_ttl: %{
    # 5 minutes
    short:  300_000,
    medium: 900_000,
    long:   3_600_000,
    daily:  86_400_000
  },
  cache_categories: [:dashboard, :places, :routes, :trips, :interests, :statistics]

# Guardian configuration
config :phoenix_backend, RouteWiseApi.Guardian,
  issuer: "phoenix_backend",
  secret_key:
    System.get_env("GUARDIAN_SECRET_KEY") || "your-secret-key-here-change-in-production",
  ttl: {7, :days}

# Ueberauth configuration
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

# Google OAuth configuration moved to runtime.exs to properly read environment variables

# Google Places API configuration
config :phoenix_backend, :google_places_api_key, System.get_env("GOOGLE_PLACES_API_KEY")

# Google Directions API configuration
config :phoenix_backend, :google_directions_api_key, System.get_env("GOOGLE_DIRECTIONS_API_KEY")

# LocationIQ API configuration
config :phoenix_backend, :location_iq,
  api_key: System.get_env("LOCATION_IQ_API_KEY") || "pk.09fd3ae905361881e63bfe61a679880a"

# LocationIQ Autocomplete API key (for hybrid autocomplete service)
config :phoenix_backend, :location_iq_api_key, System.get_env("LOCATION_IQ_API_KEY") || "pk.09fd3ae905361881e63bfe61a679880a"

# Express.js integration configuration
config :phoenix_backend,
  express_base_url: System.get_env("EXPRESS_BASE_URL") || "http://localhost:3001/api"

# Tile Cache configuration
config :phoenix_backend, RouteWiseApi.TileCache,
  max_memory_mb: 500,
  default_ttl_days: 7,
  cleanup_interval_minutes: 5,
  enable_statistics: true

# OSM Tile Client configuration
config :phoenix_backend, RouteWiseApi.OSMTileClient,
  user_agent: "RouteWise/1.0 (contact@example.com)",
  max_requests_per_second: 2,
  max_retries: 3,
  timeout_ms: 10_000,
  servers: [
    "https://tile.openstreetmap.org",
    "https://a.tile.openstreetmap.org",
    "https://b.tile.openstreetmap.org",
    "https://c.tile.openstreetmap.org"
  ]

# Image Service configuration
config :phoenix_backend, RouteWiseApi.ImageService,
  base_url: "http://localhost:4001",
  serve_locally: true,
  image_formats: [:webp, :jpg, :png, :svg],
  enable_fallbacks: true,
  cache_max_age: 86_400  # 24 hours

# Redis configuration (production-oriented)
config :phoenix_backend, RouteWiseApi.Caching.Backend.Redis,
  host: "localhost",
  port: 6379,
  database: 0,
  password: nil,
  pool_size: 10

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
