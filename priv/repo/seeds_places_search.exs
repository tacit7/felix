# Places Search Seed Data
#
# Seeds the new places search system with a curated set of locations and their aliases.
# Run with: mix run priv/repo/seeds_places_search.exs

alias RouteWiseApi.Repo

defmodule PlaceSearchSeed do
  @moduledoc """
  Seed data for the places search system with aliases.
  """

  def run do
    IO.puts("🌍 Seeding places search system...")

    # Clear existing data (SQL approach since we don't have schemas yet)
    Repo.query!("DELETE FROM place_aliases")
    Repo.query!("DELETE FROM places")

    # Seed places and their aliases
    places_data()
    |> Enum.each(&create_place_with_aliases/1)

    IO.puts("✅ Places search system seeded successfully!")
    print_stats()
  end

  defp create_place_with_aliases({place_attrs, aliases}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    # Insert place using raw SQL
    {:ok, result} = Repo.query("""
      INSERT INTO places (name, code, kind, latitude, longitude, popularity, metadata, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id
    """, [
      place_attrs.name,
      place_attrs[:code],
      place_attrs.kind,
      place_attrs[:latitude],
      place_attrs[:longitude],
      place_attrs[:popularity] || 0,
      Jason.encode!(place_attrs[:metadata] || %{}),
      now,
      now
    ])

    [[place_id]] = result.rows

    # Insert aliases with priority (higher number = higher priority)
    aliases
    |> Enum.with_index()
    |> Enum.each(fn {alias_name, index} ->
      Repo.query!("""
        INSERT INTO place_aliases (place_id, alias, priority, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5)
      """, [
        place_id,
        alias_name,
        length(aliases) - index, # Higher priority for earlier aliases
        now,
        now
      ])
    end)

    IO.puts("  ✓ #{place_attrs.name} with #{length(aliases)} aliases")
  end

  defp places_data do
    [
      # US Virgin Islands - Primary target with many variants
      {
        %{
          name: "United States Virgin Islands",
          code: "USVI",
          kind: "region",
          latitude: 17.789187,
          longitude: -64.7080574,
          popularity: 85,
          metadata: %{
            country: "United States",
            region: "Caribbean",
            description: "US territory in the Caribbean"
          }
        },
        [
          "US Virgin Islands",
          "U.S. Virgin Islands",
          "USVI",
          "Virgin Islands US",
          "American Virgin Islands",
          "St. Thomas",
          "St. John",
          "St. Croix"
        ]
      },

      # New York City
      {
        %{
          name: "New York City",
          code: "NYC",
          kind: "city",
          latitude: 40.7128,
          longitude: -74.0060,
          popularity: 100,
          metadata: %{
            country: "United States",
            state: "New York",
            description: "The most populous city in the United States"
          }
        },
        [
          "NYC",
          "New York",
          "Manhattan",
          "The Big Apple",
          "Brooklyn",
          "Queens",
          "Bronx",
          "Staten Island"
        ]
      },

      # Los Angeles
      {
        %{
          name: "Los Angeles",
          code: "LAX",
          kind: "city",
          latitude: 34.0522,
          longitude: -118.2437,
          popularity: 95,
          metadata: %{
            country: "United States",
            state: "California",
            description: "The second most populous city in the United States"
          }
        },
        [
          "LA",
          "L.A.",
          "Los Angeles",
          "City of Angels",
          "Hollywood",
          "Beverly Hills",
          "Santa Monica"
        ]
      },

      # Yellowstone National Park
      {
        %{
          name: "Yellowstone National Park",
          code: "YELL",
          kind: "poi",
          latitude: 44.4280,
          longitude: -110.5885,
          popularity: 90,
          metadata: %{
            country: "United States",
            states: ["Wyoming", "Montana", "Idaho"],
            description: "First national park in the world"
          }
        },
        [
          "Yellowstone",
          "Yellowstone NP",
          "Old Faithful",
          "Grand Prismatic"
        ]
      },

      # Grand Canyon National Park
      {
        %{
          name: "Grand Canyon National Park",
          code: "GRCA",
          kind: "poi",
          latitude: 36.1069,
          longitude: -112.1129,
          popularity: 88,
          metadata: %{
            country: "United States",
            state: "Arizona",
            description: "One of the most visited national parks"
          }
        },
        [
          "Grand Canyon",
          "Grand Canyon NP",
          "South Rim",
          "North Rim"
        ]
      },

      # Puerto Rico (existing location that should work better)
      {
        %{
          name: "Puerto Rico",
          code: "PR",
          kind: "region",
          latitude: 18.2208,
          longitude: -66.5901,
          popularity: 80,
          metadata: %{
            country: "United States",
            region: "Caribbean",
            description: "Commonwealth of Puerto Rico"
          }
        },
        [
          "PR",
          "Commonwealth of Puerto Rico",
          "San Juan",
          "Isla del Encanto",
          "Borinquen"
        ]
      },

      # Washington DC
      {
        %{
          name: "Washington, D.C.",
          code: "DC",
          kind: "city",
          latitude: 38.9072,
          longitude: -77.0369,
          popularity: 85,
          metadata: %{
            country: "United States",
            description: "Capital of the United States"
          }
        },
        [
          "Washington DC",
          "DC",
          "D.C.",
          "The District",
          "Capitol",
          "White House"
        ]
      },

      # Las Vegas
      {
        %{
          name: "Las Vegas",
          code: "LAS",
          kind: "city",
          latitude: 36.1699,
          longitude: -115.1398,
          popularity: 85,
          metadata: %{
            country: "United States",
            state: "Nevada",
            description: "Entertainment capital of the world"
          }
        },
        [
          "Vegas",
          "Sin City",
          "The Strip",
          "Las Vegas Strip"
        ]
      }
    ]
  end

  defp print_stats do
    {:ok, places_result} = Repo.query("SELECT COUNT(*) FROM places")
    [[places_count]] = places_result.rows

    {:ok, aliases_result} = Repo.query("SELECT COUNT(*) FROM place_aliases")
    [[aliases_count]] = aliases_result.rows

    IO.puts("\n📊 Final Stats:")
    IO.puts("   Places: #{places_count}")
    IO.puts("   Aliases: #{aliases_count}")
  end
end

# Run the seed
PlaceSearchSeed.run()