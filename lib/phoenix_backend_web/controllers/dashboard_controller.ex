defmodule RouteWiseApiWeb.DashboardController do
  use RouteWiseApiWeb, :controller
  
  alias RouteWiseApi.Trips
  alias RouteWiseApi.Interests
  alias RouteWiseApi.POI
  alias RouteWiseApi.Integrations.ExpressClient

  @doc """
  Custom dashboard endpoint that aggregates data for the frontend dashboard.
  Returns trips, suggested user interests, and categories in a single response.
  """
  def index(conn, _params) do
    # Get current user from Guardian if authenticated
    current_user = Guardian.Plug.current_resource(conn)
    
    # Aggregate dashboard data
    dashboard_data = %{
      trips: get_trips_data(current_user),
      suggested_interests: get_suggested_interests(current_user),
      categories: get_categories(),
      user: get_user_data(current_user),
      stats: get_dashboard_stats(current_user)
    }
    
    json(conn, %{
      success: true,
      data: dashboard_data,
      timestamp: DateTime.utc_now()
    })
  end
  
  # Private helper functions
  
  defp get_trips_data(nil) do
    # For unauthenticated users, return public/featured trips
    %{
      user_trips: [],
      suggested_trips: get_public_trips(),
      recent_trips: [],
      trip_count: 0
    }
  end
  
  defp get_trips_data(user) do
    user_trips = Trips.list_user_trips(user.id)
    
    %{
      user_trips: format_trips(user_trips),
      suggested_trips: get_suggested_trips_for_user(user),
      recent_trips: get_recent_trips(user),
      trip_count: length(user_trips)
    }
  end
  
  defp get_suggested_interests(nil) do
    # For unauthenticated users, return popular interests
    [
      %{id: "adventure", name: "Adventure", category: "activity", popularity: 85},
      %{id: "culture", name: "Culture & History", category: "activity", popularity: 78},
      %{id: "food", name: "Food & Dining", category: "activity", popularity: 92},
      %{id: "nature", name: "Nature & Parks", category: "activity", popularity: 76},
      %{id: "shopping", name: "Shopping", category: "activity", popularity: 64}
    ]
  end
  
  defp get_suggested_interests(user) do
    # Get auth token for Express.js integration
    auth_token = get_auth_token_for_express(user)
    
    # Try to get interests from Express.js service first
    case ExpressClient.get_user_interests(user.id, auth_token) do
      {:ok, express_interests} ->
        # Transform Express.js format to our dashboard format
        express_interests
        |> Enum.filter(& &1["isEnabled"] == false)  # Get disabled interests as suggestions
        |> Enum.take(5)
        |> Enum.map(fn interest ->
          %{
            id: interest["categoryId"],
            name: interest["category"]["displayName"],
            category: interest["category"]["name"],
            popularity: calculate_interest_popularity(interest["categoryId"])
          }
        end)
      
      {:error, reason} ->
        # Fallback to Phoenix-based interests if Express.js unavailable
        require Logger
        Logger.warning("Express.js interests unavailable: #{inspect(reason)}")
        get_fallback_suggested_interests(user)
    end
  end
  
  defp get_categories do
    %{
      trip_types: [
        %{id: "road_trip", name: "Road Trip", icon: "🚗"},
        %{id: "city_break", name: "City Break", icon: "🏙️"},
        %{id: "adventure", name: "Adventure", icon: "🏔️"},
        %{id: "relaxation", name: "Relaxation", icon: "🏖️"},
        %{id: "cultural", name: "Cultural", icon: "🏛️"}
      ],
      poi_categories: [
        %{id: "restaurant", name: "Restaurants", icon: "🍴", count: get_poi_count_by_category("restaurant")},
        %{id: "attraction", name: "Attractions", icon: "🎭", count: get_poi_count_by_category("attraction")},
        %{id: "park", name: "Parks", icon: "🌳", count: get_poi_count_by_category("park")},
        %{id: "museum", name: "Museums", icon: "🏛️", count: get_poi_count_by_category("museum")},
        %{id: "shopping", name: "Shopping", icon: "🛍️", count: get_poi_count_by_category("shopping")}
      ],
      interest_categories: [
        %{id: "activity", name: "Activities"},
        %{id: "cuisine", name: "Cuisine"},
        %{id: "accommodation", name: "Accommodation"},
        %{id: "transportation", name: "Transportation"}
      ]
    }
  end
  
  defp get_user_data(nil), do: nil
  
  defp get_user_data(user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      profile_complete: is_profile_complete?(user),
      member_since: user.inserted_at,
      preferences: get_user_preferences(user)
    }
  end
  
  defp get_dashboard_stats(nil) do
    %{
      total_destinations: get_public_destination_count(),
      total_pois: POI.count_all_pois(),
      popular_destinations: get_popular_destinations()
    }
  end
  
  defp get_dashboard_stats(user) do
    %{
      user_trips: Trips.count_user_trips(user.id),
      saved_places: count_user_saved_places(user.id),
      total_destinations: get_public_destination_count(),
      total_pois: POI.count_all_pois(),
      popular_destinations: get_popular_destinations()
    }
  end
  
  # Placeholder implementations - these would connect to actual data
  
  defp get_public_trips do
    [
      %{
        id: "featured-1",
        title: "Pacific Coast Highway",
        description: "Scenic coastal drive from San Francisco to Los Angeles",
        duration: "7 days",
        distance: "500 miles",
        image_url: "/images/pch.jpg",
        featured: true
      },
      %{
        id: "featured-2", 
        title: "Great Lakes Circle",
        description: "Explore the stunning Great Lakes region",
        duration: "10 days",
        distance: "1200 miles",
        image_url: "/images/great-lakes.jpg",
        featured: true
      }
    ]
  end
  
  defp get_suggested_trips_for_user(_user) do
    # This would use ML/recommendation algorithms based on user interests
    get_public_trips()
  end
  
  defp get_recent_trips(_user) do
    # Return user's most recently accessed trips
    []
  end
  
  defp format_trips(trips) do
    Enum.map(trips, fn trip ->
      %{
        id: trip.id,
        title: trip.title,
        description: trip.description,
        start_date: trip.start_date,
        end_date: trip.end_date,
        status: trip.status,
        created_at: trip.inserted_at,
        updated_at: trip.updated_at
      }
    end)
  end
  
  defp calculate_interest_popularity(_interest_id) do
    # This would calculate based on actual user data
    Enum.random(60..95)
  end
  
  defp get_poi_count_by_category(_category) do
    # This would query actual POI counts
    Enum.random(50..500)
  end
  
  defp is_profile_complete?(_user) do
    # Check if user has completed their profile
    true
  end
  
  defp get_user_preferences(_user) do
    %{
      preferred_trip_length: "week",
      budget_range: "moderate",
      travel_style: "balanced"
    }
  end
  
  defp get_public_destination_count do
    # Count of available destinations
    247
  end
  
  defp count_user_saved_places(_user_id) do
    # Count user's saved POIs
    0
  end
  
  defp get_popular_destinations do
    [
      %{name: "San Francisco, CA", trip_count: 45},
      %{name: "New York, NY", trip_count: 38},
      %{name: "Chicago, IL", trip_count: 32},
      %{name: "Los Angeles, CA", trip_count: 29},
      %{name: "Seattle, WA", trip_count: 24}
    ]
  end

  # Express.js Integration Helper Functions

  defp get_auth_token_for_express(user) do
    # Extract JWT token from Guardian for Express.js communication
    case Guardian.encode_and_sign(RouteWiseApi.Guardian, user) do
      {:ok, token, _claims} -> token
      {:error, _reason} -> nil
    end
  end

  defp get_fallback_suggested_interests(user) do
    # Fallback implementation using Phoenix contexts
    current_interests = Interests.get_user_interests(user.id)
    current_interest_ids = Enum.map(current_interests, & &1.interest_id)
    
    all_interests = Interests.list_interest_categories()
    
    suggested = Enum.reject(all_interests, fn interest ->
      interest.id in current_interest_ids
    end)
    
    suggested
    |> Enum.take(5)
    |> Enum.map(fn interest ->
      %{
        id: interest.id,
        name: interest.name,
        category: interest.category,
        popularity: calculate_interest_popularity(interest.id)
      }
    end)
  end
end