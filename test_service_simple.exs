# Simple test to verify PlaceSearch service layer
IO.puts("Testing PlaceSearch.search_stats/0...")

try do
  stats = RouteWiseApi.PlaceSearch.search_stats()
  IO.inspect(stats, label: "✅ PlaceSearch Stats")

  IO.puts("\nTesting PlaceSearch.search/1...")
  {:ok, results} = RouteWiseApi.PlaceSearch.search("usvi")
  IO.inspect(results, label: "✅ USVI Search Results", limit: :infinity)

  IO.puts("\n✅ Service layer tests completed successfully!")
rescue
  error ->
    IO.puts("❌ Error: #{Exception.message(error)}")
    IO.puts("Stack trace:")
    IO.puts(Exception.format_stacktrace(__STACKTRACE__))
end