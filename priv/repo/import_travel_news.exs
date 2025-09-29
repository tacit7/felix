import Ecto.Query
alias RouteWiseApi.Repo
alias RouteWiseApi.Blog.TravelNewsArticle

# Read the travel news JSON data
json_file_path = "/Users/urielmaldonado/projects/phoenix-backend/data/travel-news-travel-news-{{$json[\"fileName\"]}}"

IO.puts("🚀 Starting travel news import from #{json_file_path}")

case File.read(json_file_path) do
  {:ok, json_content} ->
    case Jason.decode(json_content) do
      {:ok, %{"articles" => articles, "count" => count, "generatedAt" => generated_at}} ->
        IO.puts("📊 Found #{count} articles to import, generated at #{generated_at}")

        # Parse generated_at timestamp
        {:ok, generated_datetime, _offset} = DateTime.from_iso8601(generated_at)

        successful_imports = 0
        failed_imports = 0
        duplicate_skipped = 0

        {successful_imports, failed_imports, duplicate_skipped} =
          Enum.reduce(articles, {0, 0, 0}, fn article, {success, failed, skipped} ->
            # Prepare article data with generated_at timestamp
            article_data =
              article
              |> Map.put("generated_at", generated_at)
              |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

            case TravelNewsArticle.from_json_changeset(article_data) do
              %Ecto.Changeset{valid?: true} = changeset ->
                case Repo.insert(changeset) do
                  {:ok, _article} ->
                    IO.puts("✅ Imported: #{article["title"]}")
                    {success + 1, failed, skipped}
                  {:error, %Ecto.Changeset{errors: errors}} ->
                    case Keyword.get(errors, :link) do
                      {_, [constraint: :unique, constraint_name: _]} ->
                        IO.puts("⏭️  Skipped duplicate: #{article["title"]}")
                        {success, failed, skipped + 1}
                      _ ->
                        IO.puts("❌ Failed to import: #{article["title"]} - #{inspect(errors)}")
                        {success, failed + 1, skipped}
                    end
                end
              changeset ->
                IO.puts("❌ Invalid data for: #{article["title"]} - #{inspect(changeset.errors)}")
                {success, failed + 1, skipped}
            end
          end)

        IO.puts("\n📈 Import Summary:")
        IO.puts("✅ Successfully imported: #{successful_imports}")
        IO.puts("❌ Failed imports: #{failed_imports}")
        IO.puts("⏭️  Duplicate articles skipped: #{duplicate_skipped}")
        IO.puts("📊 Total processed: #{successful_imports + failed_imports + duplicate_skipped}")

        # Verify final count
        total_articles = Repo.aggregate(TravelNewsArticle, :count, :id)
        IO.puts("🗃️  Total articles in database: #{total_articles}")

      {:error, decode_error} ->
        IO.puts("❌ Failed to decode JSON: #{inspect(decode_error)}")
    end

  {:error, file_error} ->
    IO.puts("❌ Failed to read file: #{inspect(file_error)}")
end

IO.puts("🏁 Travel news import completed!")