# Update the Puerto Rico blog post with Seasonal Highlights section

alias RouteWiseApi.Blog
alias RouteWiseApi.Repo

# Read the updated content with seasonal highlights
content_with_seasonal = File.read!("puerto_rico_travel_guide_2025.md")

# Get the existing blog post
post_id = "811a5b39-6870-4696-8c03-5bad6c912df5"
post = Blog.get_post!(post_id)

# Update only the content with the new seasonal highlights section
updated_attrs = %{
  content: content_with_seasonal
}

# Update the blog post
case Blog.update_post(post, updated_attrs) do
  {:ok, updated_post} ->
    IO.puts("✅ Successfully updated blog post with Seasonal Highlights:")
    IO.puts("   Title: #{updated_post.title}")
    IO.puts("   Content length: #{String.length(updated_post.content)} characters")
    IO.puts("   Contains 'Seasonal Highlights': #{String.contains?(updated_post.content, "Seasonal Highlights")}")
    IO.puts("   Contains 'Festival del Lago': #{String.contains?(updated_post.content, "Festival del Lago")}")
  {:error, changeset} ->
    IO.puts("❌ Failed to update blog post:")
    IO.inspect(changeset.errors)
end

IO.puts("\n🎉 August 2025 Seasonal Highlights now live in Puerto Rico travel guide!")