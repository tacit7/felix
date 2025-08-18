# Update the Puerto Rico blog post with 2025 content

alias RouteWiseApi.Blog
alias RouteWiseApi.Repo

# Read the 2025 updated content
content_2025 = File.read!("puerto_rico_travel_guide_2025.md")

# Get the existing blog post
post_id = "811a5b39-6870-4696-8c03-5bad6c912df5"
post = Blog.get_post!(post_id)

# Updated attributes for 2025
updated_attrs = %{
  title: "Puerto Rico: Your Complete 2025 Travel Guide to the Island of Enchantment",
  slug: "puerto-rico-complete-travel-guide-2025",
  content: content_2025,
  excerpt: "Planning a trip to Puerto Rico in 2025? This comprehensive guide covers the latest developments, current pricing, digital nomad opportunities, and insider insights from the island's record-breaking tourism year.",
  meta_description: "Complete Puerto Rico travel guide 2025: latest costs, new developments, digital nomad tips, best restaurants, and insider advice from record tourism year.",
  tags: ["Puerto Rico", "Caribbean Travel", "Travel Guide 2025", "Island Vacation", "US Territory", "Digital Nomad", "El Yunque", "Old San Juan", "Beach Destinations", "Remote Work", "2025 Travel Trends"]
}

# Update the blog post
case Blog.update_post(post, updated_attrs) do
  {:ok, updated_post} ->
    IO.puts("✅ Successfully updated blog post to 2025 version:")
    IO.puts("   Title: #{updated_post.title}")
    IO.puts("   Slug: #{updated_post.slug}")
    IO.puts("   Content length: #{String.length(updated_post.content)} characters")
    IO.puts("   Tags: #{Enum.join(updated_post.tags, ", ")}")
  {:error, changeset} ->
    IO.puts("❌ Failed to update blog post:")
    IO.inspect(changeset.errors)
end

IO.puts("\n📊 Updated blog post count: #{length(Blog.list_posts())}")
IO.puts("🎯 2025 Puerto Rico travel guide is now live!")