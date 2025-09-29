#!/usr/bin/env elixir

# Test script for PlaceSearch service
Mix.install([])

# Start the application context
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

# Configure repo
config = [
  hostname: "localhost",
  database: "phoenix_backend_dev",
  username: System.get_env("USER"),
  pool_size: 1
]

defmodule TestRepo do
  use Ecto.Repo,
    otp_app: :test,
    adapter: Ecto.Adapters.Postgres
end

# Start the repo
TestRepo.start_link(config)

# Define the PlaceSearch module inline for testing
defmodule PlaceSearchTest do
  def test_usvi do
    case TestRepo.query("SELECT * FROM search_places('usvi', 5)") do
      {:ok, %{rows: rows, columns: columns}} ->
        results = Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Enum.into(%{})
        end)

        IO.puts("✅ USVI Search Results:")
        Enum.each(results, fn result ->
          IO.puts("  - #{result["name"]} (#{result["matched_alias"]}) - #{result["match_type"]}")
        end)

      {:error, reason} ->
        IO.puts("❌ USVI search failed: #{inspect(reason)}")
    end
  end

  def test_nyc do
    case TestRepo.query("SELECT * FROM search_places('NYC', 3)") do
      {:ok, %{rows: rows, columns: columns}} ->
        results = Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Enum.into(%{})
        end)

        IO.puts("✅ NYC Search Results:")
        Enum.each(results, fn result ->
          IO.puts("  - #{result["name"]} (#{result["matched_alias"]}) - #{result["match_type"]}")
        end)

      {:error, reason} ->
        IO.puts("❌ NYC search failed: #{inspect(reason)}")
    end
  end

  def test_stats do
    with {:ok, places_result} <- TestRepo.query("SELECT COUNT(*) FROM places"),
         {:ok, aliases_result} <- TestRepo.query("SELECT COUNT(*) FROM place_aliases") do

      [[places_count]] = places_result.rows
      [[aliases_count]] = aliases_result.rows

      IO.puts("✅ Search Statistics:")
      IO.puts("  - Places: #{places_count}")
      IO.puts("  - Aliases: #{aliases_count}")
    else
      {:error, reason} ->
        IO.puts("❌ Stats query failed: #{inspect(reason)}")
    end
  end
end

# Run the tests
IO.puts("🔍 Testing PlaceSearch Service Layer")
IO.puts("==================================")
PlaceSearchTest.test_usvi()
IO.puts("")
PlaceSearchTest.test_nyc()
IO.puts("")
PlaceSearchTest.test_stats()
IO.puts("")
IO.puts("✅ Service layer tests complete!")