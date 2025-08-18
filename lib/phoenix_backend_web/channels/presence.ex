defmodule RouteWiseApiWeb.Presence do
  @moduledoc """
  Phoenix Presence for tracking POI channel connections.
  
  Provides real-time tracking of connected clients and their viewport states
  for coordinated POI clustering and potential future features like collaborative
  map exploration or usage analytics.
  """
  
  use Phoenix.Presence,
    otp_app: :phoenix_backend,
    pubsub_server: RouteWiseApi.PubSub
end