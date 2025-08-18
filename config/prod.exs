import Config

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: RouteWiseApi.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Production caching with Redis backend
config :phoenix_backend, RouteWiseApi.Caching,
  backend: RouteWiseApi.Caching.Backend.Redis,
  enable_logging: false,
  debug_mode: false,
  ttl_multiplier: 1.0

# Disable assertions in production for zero runtime overhead
config :phoenix_backend, assertions: false

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
