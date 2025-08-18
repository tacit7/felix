# Reddit Travel Recommendations Scraper

Discover what people actually like to do in cities and countries by analyzing Reddit posts and comments from travel subreddits.

## Quick Start

### 1. Install Dependencies
```bash
cd reddit_scraper
pip install -r requirements.txt
```

### 2. Set Up Reddit API Credentials
1. Go to https://www.reddit.com/prefs/apps
2. Create a new app (type: "script")
3. Copy `.env.example` to `.env`
4. Add your credentials:
```bash
cp .env.example .env
# Edit .env with your Reddit API credentials
```

### 3. Run the Scraper
```bash
# Find travel recommendations for Austin, TX
python reddit_travel_scraper.py --location "Austin, TX" --limit 25

# Search specific subreddits
python reddit_travel_scraper.py --location "Puerto Rico" --subreddits "travel,solotravel,PuertoRico"

# Get more results
python reddit_travel_scraper.py --location "New York City" --limit 50
```

## What It Does

### 🔍 **Intelligent Search**
- Searches relevant travel subreddits (r/travel, r/solotravel, etc.)
- Finds location-specific subreddits (r/austin, r/NYC, etc.)
- Uses smart search terms ("Austin recommendations", "things to do Austin")

### 📝 **Comment Analysis**
- Extracts recommendations from highly-upvoted comments
- Identifies place names and attractions mentioned
- Captures context and user experiences

### 💾 **Rich Data Output**
- Post titles, scores, and URLs
- Comment recommendations with upvotes
- Extracted place names and attractions
- Summary statistics and top mentions

## Example Output

```json
{
  "location": "Austin, TX",
  "total_posts": 15,
  "posts": [
    {
      "title": "First time visiting Austin - what should I not miss?",
      "score": 127,
      "subreddit": "travel",
      "recommendations": [
        {
          "score": 45,
          "text": "Definitely check out Franklin Barbecue and walk around South by Southwest district...",
          "places": ["Franklin Barbecue", "South by Southwest", "Zilker Park"]
        }
      ]
    }
  ],
  "summary": {
    "top_mentioned_places": [
      ["Franklin Barbecue", 8],
      ["Zilker Park", 6],
      ["South Congress", 5]
    ]
  }
}
```

## Use Cases for RouteWise

### 🗺️ **Route Planning Enhancement**
- **POI Discovery**: Find attractions not in typical tourist guides
- **Local Favorites**: Get insider recommendations from residents
- **Hidden Gems**: Discover places locals actually visit

### 📊 **Data Integration**
- **Validate Existing POIs**: Cross-reference with user preferences
- **Popularity Scoring**: Weight places by Reddit mention frequency
- **Trend Analysis**: Track what's trending in different cities

### 🎯 **User Personalization**
- **Interest Matching**: Match user interests with Reddit recommendations
- **Authentic Experiences**: Show "real" local experiences vs tourist traps
- **Community Validation**: Use upvotes as quality signals

## Advanced Usage

### Custom Subreddits
```bash
# Target specific communities
python reddit_travel_scraper.py --location "Tokyo" --subreddits "japan,solotravel,backpacking,JapanTravel"
```

### Batch Processing
```bash
# Create a cities list and process multiple locations
for city in "Austin,TX" "San Antonio,TX" "Houston,TX"; do
    python reddit_travel_scraper.py --location "$city" --limit 30
done
```

### Integration with Phoenix Backend
The scraper outputs JSON that can be easily imported into your Phoenix backend:

```elixir
# Process Reddit recommendations in Phoenix
def process_reddit_recommendations(json_file) do
  data = File.read!(json_file) |> Jason.decode!()
  
  for post <- data["posts"] do
    for rec <- post["recommendations"] do
      for place <- rec["places"] do
        # Create POI entries or validate existing ones
        Places.create_or_validate_poi(%{
          name: place,
          source: "reddit",
          confidence_score: rec["score"],
          location: data["location"]
        })
      end
    end
  end
end
```

## Rate Limiting & Best Practices

- **Built-in delays**: 1-2 seconds between requests
- **Respect Reddit's ToS**: Don't overwhelm their servers
- **Read-only access**: Only reads public data
- **No personal data**: Doesn't collect private user information

## Troubleshooting

### Authentication Issues
```bash
# Test your credentials
python -c "import praw; r = praw.Reddit(...); print(r.user.me())"
```

### No Results Found
- Try broader search terms
- Check if subreddits exist and are accessible
- Some location subreddits might be private or inactive

### Rate Limiting
- Reduce `--limit` parameter
- Add longer delays in the code if needed
- Reddit allows ~60 requests per minute

## Integration Ideas

1. **Weekly Reddit POI Updates**: Run scraper weekly to find trending places
2. **User Interest Matching**: Match Reddit recommendations to user preferences  
3. **Route Enhancement**: Add Reddit-discovered places to existing routes
4. **Popularity Scoring**: Use Reddit upvotes to rank POI recommendations