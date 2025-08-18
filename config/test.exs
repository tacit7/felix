import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :phoenix_backend, RouteWiseApi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "phoenix_backend_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  types: RouteWiseApi.PostgresTypes

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phoenix_backend, RouteWiseApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "nPVpJov7zjQZszhbpOtxmshk8iKaBueWP0njL0BB1Xl3PFTqdIgfAwhPTEXP/rKy",
  server: false

# In test we don't send emails
config :phoenix_backend, RouteWiseApi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable assertions in test
config :phoenix_backend, assertions: true
