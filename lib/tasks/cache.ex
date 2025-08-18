defmodule Mix.Tasks.Cache do
  @moduledoc """
  Mix tasks for managing the RouteWise cache system.

  Available commands:

  - `mix cache.clear` - Clear all cache entries
  - `mix cache.stats` - Show cache statistics
  - `mix cache.health` - Check cache system health
  - `mix cache.warm` - Warm cache with common data
  - `mix cache.test` - Test cache operations
  - `mix cache.disable` - Disable caching for debugging
  - `mix cache.enable` - Enable caching for normal operation
  """

  use Mix.Task
  require Logger

  @shortdoc "Manage RouteWise cache system"

  def run([]), do: show_help()

  def run(["clear"]) do
    start_app()

    case RouteWiseApi.Caching.clear_all_cache() do
      :ok ->
        IO.puts("✅ All cache entries cleared successfully")

      {:error, reason} ->
        IO.puts("❌ Failed to clear cache: #{inspect(reason)}")
        exit(:error)
    end
  end

  def run(["stats"]) do
    start_app()

    stats = RouteWiseApi.Caching.get_cache_statistics()

    IO.puts("\n🏢 Cache Statistics")
    IO.puts("==================")

    # Backend info
    backend_stats = stats.backend_stats
    IO.puts("Backend:      #{Map.get(backend_stats, :backend, "unknown")}")
    IO.puts("Environment:  #{stats.environment}")
    IO.puts("Health:       #{Map.get(backend_stats, :health_status, "unknown")}")

    # Memory usage
    if memory = Map.get(backend_stats, :memory_usage) do
      memory_mb = div(memory, 1024 * 1024)
      IO.puts("Memory:       #{memory_mb} MB")
    end

    # Cache counts
    if total_keys = Map.get(backend_stats, :total_keys) do
      expired_keys = Map.get(backend_stats, :expired_keys, 0)
      active_keys = total_keys - expired_keys

      IO.puts("\n📊 Cache Entries")
      IO.puts("Total:        #{total_keys}")
      IO.puts("Active:       #{active_keys}")
      IO.puts("Expired:      #{expired_keys}")
    end

    # TTL policies
    IO.puts("\n⏱️  TTL Policies")

    Enum.each(stats.ttl_policies, fn {category, ttl_info} ->
      IO.puts("#{String.capitalize(to_string(category))}: #{ttl_info}")
    end)

    IO.puts("\n🕒 Generated: #{stats.timestamp}")
  end

  def run(["health"]) do
    start_app()

    case RouteWiseApi.Caching.health_check() do
      {:ok, health_data} ->
        IO.puts("✅ Cache system is healthy")
        IO.puts("Backend:   #{health_data.backend}")
        IO.puts("Status:    #{health_data.status}")
        IO.puts("Checked:   #{health_data.timestamp}")

      {:error, health_data} ->
        IO.puts("❌ Cache system is unhealthy")
        IO.puts("Backend:   #{health_data.backend}")
        IO.puts("Status:    #{health_data.status}")
        IO.puts("Reason:    #{inspect(health_data.reason)}")
        IO.puts("Checked:   #{health_data.timestamp}")
        exit(:error)
    end
  end

  def run(["warm"]) do
    start_app()

    IO.puts("🔥 Warming cache with common data...")

    # Warm common interest categories
    warm_interest_categories()

    # Warm public trips
    warm_public_trips()

    # Warm statistics
    warm_statistics()

    IO.puts("✅ Cache warming completed")
  end

  def run(["test"]) do
    start_app()

    IO.puts("🧪 Testing cache operations...")

    test_key = "cache_test_#{System.monotonic_time()}"
    test_value = %{test: true, timestamp: DateTime.utc_now()}
    # 5 seconds
    ttl = 5000

    # Test write
    IO.write("- Testing cache write... ")

    case RouteWiseApi.Caching.backend().put(test_key, test_value, ttl) do
      :ok ->
        IO.puts("✅")

      error ->
        IO.puts("❌ #{inspect(error)}")
        exit(:error)
    end

    # Test read
    IO.write("- Testing cache read... ")

    case RouteWiseApi.Caching.backend().get(test_key) do
      {:ok, ^test_value} ->
        IO.puts("✅")

      {:ok, other_value} ->
        IO.puts("❌ Data corruption - got: #{inspect(other_value)}")
        exit(:error)

      :error ->
        IO.puts("❌ Read failed")
        exit(:error)
    end

    # Test delete
    IO.write("- Testing cache delete... ")

    case RouteWiseApi.Caching.backend().delete(test_key) do
      :ok ->
        IO.puts("✅")

      error ->
        IO.puts("❌ #{inspect(error)}")
        exit(:error)
    end

    # Verify deletion
    IO.write("- Verifying deletion... ")

    case RouteWiseApi.Caching.backend().get(test_key) do
      :error ->
        IO.puts("✅")

      {:ok, _} ->
        IO.puts("❌ Key still exists after deletion")
        exit(:error)
    end

    IO.puts("\n✅ All cache tests passed!")
  end

  def run(["invalidate", user_id]) do
    start_app()

    IO.puts("🗑️  Invalidating caches for user: #{user_id}")

    RouteWiseApi.Caching.invalidate_user_cache(user_id)

    IO.puts("✅ User cache invalidated")
  end

  def run(["help"]), do: show_help()
  def run(_), do: show_help()

  # Private functions

  defp start_app do
    Mix.Task.run("app.start")
  end

  defp show_help do
    IO.puts("""

    🗂️  RouteWise Cache Management

    Available commands:

      mix cache.clear              Clear all cache entries
      mix cache.stats              Show detailed cache statistics
      mix cache.health             Check cache system health
      mix cache.warm               Warm cache with common data
      mix cache.test               Test cache operations
      mix cache.invalidate <id>    Invalidate user cache
      mix cache.help               Show this help

    Examples:

      mix cache.clear                    # Clear everything
      mix cache.stats                    # Show cache info
      mix cache.invalidate 123           # Clear user 123's cache
      mix cache.warm                     # Pre-load common data

    """)
  end

  defp warm_interest_categories do
    IO.write("  - Interest categories... ")

    try do
      # This would call your actual interest loading logic
      categories = RouteWiseApi.Interests.list_interest_categories()
      RouteWiseApi.Caching.put_interest_categories_cache(categories)
      IO.puts("✅")
    rescue
      error ->
        IO.puts("⚠️  #{inspect(error)}")
    end
  end

  defp warm_public_trips do
    IO.write("  - Public trips... ")

    try do
      # This would call your actual trips loading logic
      trips = RouteWiseApi.Trips.list_public_trips()
      RouteWiseApi.Caching.put_public_trips_cache(trips)
      IO.puts("✅")
    rescue
      error ->
        IO.puts("⚠️  #{inspect(error)}")
    end
  end

  defp warm_statistics do
    IO.write("  - Application statistics... ")

    try do
      # Generate basic stats
      stats = %{
        total_users: count_users(),
        total_trips: count_trips(),
        cache_backend: RouteWiseApi.Caching.Config.backend(),
        warmed_at: DateTime.utc_now()
      }

      RouteWiseApi.Caching.put_statistics_cache(stats)
      IO.puts("✅")
    rescue
      error ->
        IO.puts("⚠️  #{inspect(error)}")
    end
  end

  defp count_users do
    try do
      RouteWiseApi.Accounts.count_users()
    rescue
      _ -> 0
    end
  end

  defp count_trips do
    try do
      RouteWiseApi.Trips.count_trips()
    rescue
      _ -> 0
    end
  end
end
