defmodule RouteWiseApiWeb.UserSocket do
  @moduledoc """
  WebSocket and long-polling transport for real-time features.

  Handles authentication and channel routing for Phoenix channels including
  POI clustering, real-time notifications, and future collaborative features.

  ## Channels

  - `poi:viewport` - Real-time POI clustering for map viewports
  - `trip:user:<user_id>` - Trip management and real-time collaboration (authenticated only)

  ## Authentication

  Supports both authenticated and anonymous connections:
  - Anonymous: Full access to POI clustering (read-only)
  - Authenticated: Trip management, real-time collaboration, trip sharing

  ## Configuration

  Configures transport options for optimal real-time performance:
  - WebSocket with 60s timeout
  - Long polling fallback with 10s timeout
  - Cross-origin support for frontend integration
  """

  use Phoenix.Socket

  # Channel routing
  channel "poi:*", RouteWiseApiWeb.POIChannel
  channel "trip:*", RouteWiseApiWeb.TripChannel
  channel "scraping:*", RouteWiseApiWeb.ScrapingChannel
  channel "location:*", RouteWiseApiWeb.ScrapingChannel

  # Socket params are passed from the client and can be used
  # to verify and authenticate a user. After verification,
  # you can put default assigns into the socket that will
  # be set for all channels, ie:
  #
  #     {:ok, socket |> assign(:user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`. To control the
  # response the client receives in that case, define `auth_error/3`.
  #
  # See `Phoenix.Token` documentation for examples in performing token
  # verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # Verify JWT token for authenticated features
    case RouteWiseApi.Guardian.decode_and_verify(token) do
      {:ok, %{"sub" => user_id}} ->
        case RouteWiseApi.Accounts.get_user(user_id) do
          %RouteWiseApi.Accounts.User{} = user ->
            socket = socket
            |> assign(:user_id, user.id)
            |> assign(:current_user, user)
            |> assign(:authenticated, true)
            
            {:ok, socket}
          nil ->
            # Token valid but user not found - deny connection
            :error
        end
      {:error, _reason} ->
        # Invalid token - deny connection
        :error
    end
  end

  @impl true
  def connect(_params, socket, _connect_info) do
    # Allow anonymous connections for POI clustering
    socket = assign(socket, :authenticated, false)
    {:ok, socket}
  end

  # Socket ID for client identification and connection management
  # If you want to force disconnection of a user's socket on logout,
  # you can return the user's ID here. For anonymous users, return nil.
  @impl true
  def id(%{assigns: %{user_id: user_id}}), do: "user_socket:#{user_id}"
  def id(_socket), do: nil  # Anonymous users don't get tracked IDs

  # Authentication error handler
  def auth_error(conn, :invalid_token, _opts) do
    Plug.Conn.send_resp(conn, 401, "Invalid authentication token")
  end

  def auth_error(conn, :expired_token, _opts) do
    Plug.Conn.send_resp(conn, 401, "Authentication token expired")
  end

  def auth_error(conn, _reason, _opts) do
    Plug.Conn.send_resp(conn, 401, "Authentication failed")
  end
end