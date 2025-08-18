# Blog seed file to create the Puerto Rico travel guide blog post

alias RouteWiseApi.Blog
alias RouteWiseApi.Repo

# Read the Puerto Rico travel guide content
content = File.read!("puerto_rico_travel_guide.md")

# Create the blog post
puerto_rico_post_attrs = %{
  title: "Puerto Rico: Your Complete Guide to the Island of Enchantment (2024)",
  slug: "puerto-rico-complete-travel-guide-2024",
  content: content,
  excerpt: "Planning a trip to Puerto Rico? This comprehensive guide covers everything you need to know based on recent traveler experiences and insights from 2023-2024. From hidden gems to practical tips, discover the real Puerto Rico beyond the tourist traps.",
  featured_image: "/images/puerto-rico-hero.jpg",
  author: "RouteWise Travel Team",
  published: true,
  published_at: DateTime.utc_now(),
  meta_description: "Complete Puerto Rico travel guide 2024: costs, transportation, hidden gems, best time to visit, and insider tips from recent travelers.",
  tags: ["Puerto Rico", "Caribbean Travel", "Travel Guide", "Island Vacation", "US Territory", "El Yunque", "Old San Juan", "Beach Destinations", "Travel Tips", "2024 Travel"]
}

case Blog.create_post(puerto_rico_post_attrs) do
  {:ok, post} ->
    IO.puts("✅ Successfully created blog post: #{post.title}")
    IO.puts("   Slug: #{post.slug}")
    IO.puts("   Published: #{post.published}")
  {:error, changeset} ->
    IO.puts("❌ Failed to create blog post:")
    IO.inspect(changeset.errors)
end

IO.puts("\n📊 Blog post count: #{length(Blog.list_posts())}")