defmodule RouteWiseApiWeb.Router do
  use RouteWiseApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Ueberauth
  end

  pipeline :oauth do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_secure_browser_headers
    plug Ueberauth
  end

  pipeline :auth do
    plug :accepts, ["json"]
    plug :fetch_cookies
    plug RouteWiseApiWeb.Plugs.UnifiedAuth
  end

  pipeline :authenticated do
    plug :accepts, ["json"]
    plug :fetch_cookies
    plug RouteWiseApiWeb.Plugs.UnifiedAuth
    plug RouteWiseApiWeb.Plugs.UnifiedAuth, :require_auth
  end

  pipeline :tiles do
    plug :accepts, ["png", "json"]
    plug :fetch_cookies
  end

  # Authentication routes (no auth required)
  scope "/api/auth", RouteWiseApiWeb do
    pipe_through :api

    # Standard auth
    post "/register", AuthController, :register
    post "/login", AuthController, :login
    post "/logout", AuthController, :logout
    
    # Development only - mock authentication
    if Mix.env() == :dev do
      get "/mock", AuthController, :mock_auth
    end

    # Google OAuth initiation
    # get "/google", AuthController, :google_auth
  end

  # Google OAuth routes (handles ueberauth)
  scope "/auth", RouteWiseApiWeb do
    pipe_through :oauth
    get "/google", AuthController, :request
    get "/google/callback", AuthController, :callback
  end

  # Routes that accept optional authentication
  scope "/api", RouteWiseApiWeb do
    pipe_through [:api, :auth]

    get "/health", HealthController, :check
    get "/health/google-api-usage", HealthController, :google_api_usage
    get "/maps-key", MapsController, :get_api_key

    # Backend integration monitoring endpoints
    get "/monitoring/health", MonitoringController, :health
    get "/monitoring/express", MonitoringController, :express_metrics
    get "/monitoring/cache", MonitoringController, :cache_metrics

    # Dashboard aggregation endpoint (works with or without auth)
    get "/dashboard", DashboardController, :index

    # Places API endpoints
    get "/places/search", PlacesController, :search
    get "/places/details/:id", PlacesController, :details
    get "/places/autocomplete", PlacesController, :autocomplete
    get "/places/city-autocomplete", PlacesController, :city_autocomplete
    get "/places/locationiq-status", PlacesController, :locationiq_status
    get "/places/nearby", PlacesController, :nearby
    get "/places/photo", PlacesController, :photo

    # Enhanced places search with aliases (POA implementation)
    get "/places/search-enhanced", PlaceSearchController, :search
    get "/places/search-stats", PlaceSearchController, :stats

    # Real-time places search with background scraping
    get "/places/live-search", PlacesLiveController, :search
    get "/places/scrape-status/:location", PlacesLiveController, :scrape_status
    get "/places/check-updates", PlacesLiveController, :check_updates

    # Public trips (no auth required)
    get "/trips/public", TripsController, :public
    
    # Shared trips (no auth required)
    get "/shared/trips/:share_token", TripSharingController, :view_shared_trip

    # Interest categories (no auth required)
    get "/interests/categories", InterestsController, :categories

    # POI endpoints (no auth required for reading)
    get "/pois", POIController, :index
    get "/pois/categories", POIController, :categories
    # Legacy nearby endpoint
    get "/pois/nearby", POIController, :nearby
    # New clustering endpoint for anonymous users
    get "/pois/clusters", POIController, :clusters
    # Map bounds search endpoint (no clustering)
    get "/pois/bounds", POIController, :bounds
    get "/pois/:id", POIController, :show

    # Consolidated route results endpoint (includes POIs, route data, maps key)
    get "/route-results", RouteResultsController, :index

    # Consolidated explore results endpoint (includes POIs near location, maps key)
    get "/explore-results", ExploreResultsController, :index
    get "/explore-results/disambiguate", ExploreResultsController, :disambiguate

    # Advanced database search endpoints (no auth required)
    get "/search", PlacesSearchController, :universal_search
    get "/search/autocomplete", PlacesSearchController, :autocomplete
    get "/search/category/:category", PlacesSearchController, :search_category
    get "/search/popular", PlacesSearchController, :popular_places
    get "/search/similar/:place_id", PlacesSearchController, :similar_places

    # Places nearby endpoints (public reading)
    get "/places/:place_id/nearby", PlacesNearbyController, :index
    get "/places/nearby/:id", PlacesNearbyController, :show
    get "/places/nearby/search", PlacesNearbyController, :search
    get "/places/:place_id/nearby/category/:category", PlacesNearbyController, :by_category
    get "/places/:place_id/nearby/distance", PlacesNearbyController, :by_distance
    get "/places/nearby/stats", PlacesNearbyController, :stats

    # Route calculation endpoints (no auth required for basic calculations)
    post "/routes/calculate", RoutesController, :calculate
    post "/routes/wizard", RoutesController, :calculate_from_wizard
    post "/routes/optimize", RoutesController, :optimize
    get "/routes/alternatives", RoutesController, :alternatives
    post "/routes/estimate", RoutesController, :estimate
    post "/routes/costs", RoutesController, :estimate_costs

    # OpenStreetMap free places search (no auth required)
    get "/osm/nearby", OSMController, :nearby
    get "/osm/category/:category", OSMController, :category
    get "/osm/coverage", OSMController, :coverage

    # Blog endpoints (public reading)
    get "/blog", BlogController, :index
    get "/blog/:slug", BlogController, :show

    # Travel news endpoints (public reading)
    get "/travel-news", TravelNewsController, :index
    get "/travel-news/recent", TravelNewsController, :recent
    get "/travel-news/subjects", TravelNewsController, :subjects
    get "/travel-news/subject/:subject", TravelNewsController, :by_subject
    get "/travel-news/:id", TravelNewsController, :show
  end

  # Tile proxy endpoints (binary data, no auth required) - TEMPORARILY DISABLED
  # scope "/api/tiles", RouteWiseApiWeb do
  #   pipe_through :tiles

  #   # OSM tile proxy with caching
  #   get "/:z/:x/:y", TileController, :tile
    
  #   # Tile cache management and statistics
  #   get "/stats", TileController, :stats
  #   delete "/cache", TileController, :clear_cache
  # end

  # Image serving endpoints (no auth required)
  scope "/api/images", RouteWiseApiWeb do
    pipe_through :api

    # POI images with size variants
    get "/pois/:poi_id/:size", ImageController, :poi_image
    
    # Category icons
    get "/categories/:category", ImageController, :category_icon
    
    # Fallback/placeholder images
    get "/fallbacks/:type", ImageController, :fallback_image
    
    # UI assets (logos, markers, etc.)
    get "/ui/:asset_type", ImageController, :ui_asset
    
    # Health check and statistics
    get "/health", ImageController, :health_check
    
    # Generic image serving (catch-all)
    get "/*path", ImageController, :generic_image
  end

  # Routes that require authentication
  scope "/api", RouteWiseApiWeb do
    pipe_through [:api, :authenticated]

    # Current user endpoint (requires authentication)
    get "/auth/me", AuthController, :me

    # Trip management endpoints (authentication required)
    resources("/trips", TripsController, except: [:new, :edit])
    post "/trips/from_wizard", TripsController, :create_from_wizard
    post "/trips/explore", TripsController, :explore
    
    # Trip sharing endpoints (authentication required)
    post "/trips/:id/share", TripSharingController, :share_trip
    delete "/trips/:id/share", TripSharingController, :unshare_trip
    post "/trips/:id/collaborators", TripSharingController, :add_collaborator
    put "/trips/:id/collaborators/:collaborator_id", TripSharingController, :update_collaborator
    delete "/trips/:id/collaborators/:collaborator_id", TripSharingController, :remove_collaborator
    get "/trips/:id/activity", TripSharingController, :trip_activity

    # User interests endpoints (authentication required)
    resources("/interests", InterestsController, except: [:new, :edit, :show])

    # POI management endpoints (authentication required for CUD operations)
    post "/pois", POIController, :create
    put "/pois/:id", POIController, :update
    delete "/pois/:id", POIController, :delete

    # Authenticated route endpoints (for user's trips)
    get "/routes/trip/:trip_id", RoutesController, :get_trip_route

    # Blog management endpoints (admin only for now)
    resources("/blog", BlogController, except: [:new, :edit, :show, :index])
    post "/blog/:id/publish", BlogController, :publish

    # Places nearby management endpoints (authentication required)
    post "/places/nearby", PlacesNearbyController, :create
    post "/places/nearby/admin", PlacesNearbyController, :create_admin
    put "/places/nearby/:id", PlacesNearbyController, :update
    delete "/places/nearby/:id", PlacesNearbyController, :delete
    patch "/places/nearby/:id/toggle", PlacesNearbyController, :toggle_active
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard("/dashboard", metrics: RouteWiseApiWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
