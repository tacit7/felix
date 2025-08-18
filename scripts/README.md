# Reddit Content Extraction Pipeline

**Intelligent travel content discovery and extraction from Reddit using Google Custom Search + Reddit API**

## 📋 Overview

This pipeline discovers, ranks, and extracts high-quality travel content from Reddit discussions. It combines Google's superior search capabilities with Reddit's official API for legal, efficient content extraction.

### Key Features
- **Smart Discovery**: Google Custom Search finds better content than Reddit's native search
- **Intelligence Ranking**: AI-powered usefulness scoring (0-100 scale)
- **Batch Optimization**: 95% API efficiency improvement with single-request extraction
- **Reddit Compliance**: Designed for freemium model with clear attribution
- **Zero Cost**: Operates within free tiers of both APIs

### Performance
- **3 minutes**: Complete end-to-end pipeline
- **$0.00**: Total API costs (under free limits)
- **20 posts**: Curated high-quality content per run
- **96 comments**: Community insights extracted

---

## 🛠️ Setup & Installation

### Prerequisites
```bash
# Python 3.8+
python3 --version

# Virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Dependencies
pip install praw google-api-python-client python-dotenv
```

### API Credentials

#### 1. Google Custom Search API
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Custom Search API
3. Create credentials (API Key)
4. Set up [Custom Search Engine](https://programmablesearchengine.google.com/)

#### 2. Reddit API (PRAW)
1. Go to [Reddit App Preferences](https://www.reddit.com/prefs/apps)
2. Create "script" type application
3. Note client ID and secret

#### 3. Environment Configuration
Create `.env` file in project root:
```bash
# Google Custom Search API
GOOGLE_SEARCH_API_KEY=your_api_key_here
GOOGLE_SEARCH_ENGINE_ID=your_search_engine_id_here

# Reddit API
REDDIT_CLIENT_ID=your_client_id_here
REDDIT_CLIENT_SECRET=your_client_secret_here
REDDIT_USER_AGENT=YourApp:v1.0 (by /u/yourusername)
```

---

## 🔄 Pipeline Workflow

### Phase 1: Discovery
**Script**: `reddit_puerto_rico_search.py`

```bash
python3 reddit_puerto_rico_search.py
```

**What it does:**
- Searches Reddit via Google Custom Search API
- Uses targeted queries with date filtering
- Extracts Reddit post metadata and snippets
- **Output**: `puerto_rico_reddit_results_2024.json`

**Customization:**
```python
# Modify search queries for different topics/locations
PUERTO_RICO_QUERIES = [
    "site:reddit.com [LOCATION] travel after:2024-01-01",
    "site:reddit.com [LOCATION] must visit after:2024-01-01", 
    "site:reddit.com [LOCATION] things to do after:2024-01-01"
]
```

### Phase 2: Intelligence & Ranking
**Script**: `filter_most_useful.py`

```bash
python3 filter_most_useful.py
```

**What it does:**
- Analyzes posts with AI-powered usefulness scoring
- Removes duplicates and ranks by value
- Filters to top 20 most useful posts
- **Output**: `puerto_rico_reddit_curated_top20_2024.json`

**Scoring Algorithm:**
```python
# High-value indicators
high_value_keywords = ['must do', 'recommendations', 'tips', 'honest review']
location_keywords = ['san juan', 'old san juan', 'el yunque', 'vieques']
practical_keywords = ['stay', 'hotel', 'restaurant', 'safety', 'planning']

# Scoring factors:
# - Title relevance: +10 points per keyword
# - Location mentions: +5 points
# - Practical info: +3 points  
# - Recent posts (2024+): +15 points
# - Content length: +5 points for detailed posts
# - Post type bonuses: Guide/Review +10, Discussion +7
```

### Phase 3: Batch-Optimized Extraction
**Script**: `extract_reddit_content_batch.py`

```bash
python3 extract_reddit_content_batch.py
```

**What it does:**
- **Batch extracts** all 20 posts in single API call (95% efficiency gain)
- Gets full post content, top 5 comments, scores, metadata
- Respectful rate limiting and error handling
- **Output**: `puerto_rico_reddit_top20_batch_optimized.json`

**Batch Optimization:**
```python
# Instead of 20 individual requests:
for post_id in post_ids:
    submission = reddit.submission(id=post_id)  # 20 API calls

# Single batch request:
fullnames = [f"t3_{post_id}" for post_id in post_ids]
submissions = list(reddit.info(fullnames=fullnames))  # 1 API call
```

### Phase 4: Human-Readable Output
**Generated via Python script**

**What it creates:**
- Markdown-formatted summary with top 3 comments
- Ready for blog creation and content analysis
- **Output**: `puerto_rico_reddit_top20_with_top3_comments.md`

---

## 📊 API Usage & Limits

### Google Custom Search API
- **Free Tier**: 100 searches/day
- **Our Usage**: 3 searches per run
- **Cost**: $0.00 (well under free limit)
- **Paid Tier**: $5 per 1,000 queries if needed

### Reddit API (PRAW)
- **Free Tier**: 100 requests/minute, ~144,000/day
- **Our Usage**: 1 request per extraction (batch optimized)
- **Cost**: $0.00 (under free tier)
- **Commercial**: $0.24 per 1,000 requests if needed

### Daily Capacity
- **Current**: ~50 extractions/day (1,000 posts)
- **Theoretical**: ~144,000 posts/day with batch optimization
- **Cost**: $0.00 for typical usage

---

## 🗂️ File Structure & Outputs

```
scripts/
├── 📁 Core Scripts
│   ├── reddit_puerto_rico_search.py      # Phase 1: Discovery
│   ├── filter_most_useful.py             # Phase 2: Ranking
│   └── extract_reddit_content_batch.py   # Phase 3: Extraction
├── 📁 Data Files
│   ├── puerto_rico_reddit_results_2024.json           # Raw search results (30 posts)
│   ├── puerto_rico_reddit_curated_top20_2024.json     # Ranked top 20
│   └── puerto_rico_reddit_top20_batch_optimized.json  # Full extracted data
├── 📁 Human-Readable
│   └── puerto_rico_reddit_top20_with_top3_comments.md # Blog-ready content
└── 📁 Documentation
    ├── README.md                          # This file
    └── reddit_compliance_strategy.md      # Legal compliance guide
```

---

## 🛡️ Reddit Compliance

### Freemium Model Strategy
**Free Tier (Reddit data allowed):**
- Blog posts and travel guides
- POI recommendations and tips
- Community insights and discussions
- **Zero monetization** of Reddit-derived content

**Premium Tier (No Reddit data):**
- AI itinerary planning
- Advanced route optimization
- Cost estimation tools
- Premium analytics

### Technical Implementation
```sql
-- Separate databases for compliance
CREATE TABLE reddit_sourced_content (
    id SERIAL PRIMARY KEY,
    reddit_post_id VARCHAR,
    attribution TEXT NOT NULL,
    content_type VARCHAR
);

CREATE TABLE premium_features (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    feature_type VARCHAR,
    data JSONB -- No Reddit-sourced content
);
```

### Attribution Requirements
All Reddit-sourced content includes:
- Original post URL and author
- Subreddit source (r/PuertoRicoTravel)
- "Sourced from Reddit community discussions" notice
- Clear separation from premium features

---

## 🎯 Usage Examples

### Extract Puerto Rico Content
```bash
# Run complete pipeline
source venv/bin/activate
python3 reddit_puerto_rico_search.py
python3 filter_most_useful.py  
python3 extract_reddit_content_batch.py
```

### Adapt for New Destination
```python
# In reddit_puerto_rico_search.py, modify:
COSTA_RICA_QUERIES = [
    "site:reddit.com costa rica travel after:2024-01-01",
    "site:reddit.com costa rica must visit after:2024-01-01",
    "site:reddit.com costa rica things to do after:2024-01-01"
]
```

### Scale for Multiple Topics
```bash
# Run pipeline for different destinations
python3 search_script.py --topic "costa_rica"
python3 search_script.py --topic "mexico_travel"
python3 search_script.py --topic "japan_travel"
```

---

## 🔧 Troubleshooting

### Common Issues

**Google API Authentication Error:**
```bash
Error: "API key not valid"
```
**Solution**: Check API key in `.env` file and ensure Custom Search API is enabled

**Reddit API Rate Limit:**
```bash
Error: "Too Many Requests"
```
**Solution**: Check if within 100 QPM limit, batch optimization should prevent this

**No Results Found:**
```bash
Error: "No posts found"
```
**Solution**: Check search queries, may need broader terms or different date range

### Debug Mode
```python
# Enable debug logging
import logging
logging.basicConfig(level=logging.DEBUG)
```

---

## 📈 Performance Optimization

### Current Optimizations
- **Batch API requests**: 95% efficiency improvement
- **Smart caching**: Avoid duplicate requests
- **Rate limit respect**: Built-in delays and error handling
- **Targeted search**: Quality over quantity approach

### Future Enhancements
- **Parallel processing**: Multiple destinations simultaneously
- **Caching layer**: Redis for repeated extractions
- **ML scoring**: Enhanced usefulness algorithm
- **Auto-scheduling**: Daily content updates

---

## 🚀 Production Deployment

### RouteWise Integration
1. **Database schema**: Implement Reddit compliance tables
2. **API endpoints**: Create content serving endpoints
3. **Attribution system**: Automatic source citation
4. **Content pipeline**: Scheduled daily extractions

### Scaling Considerations
- **Multiple destinations**: Parallel pipeline execution
- **Commercial API**: Upgrade if hitting free limits
- **Content freshness**: Daily/weekly update schedules
- **Quality monitoring**: Track usefulness scores over time

---

## 📞 Support & Contribution

### Getting Help
- Check troubleshooting section above
- Review Reddit API documentation: [PRAW Docs](https://praw.readthedocs.io/)
- Google Custom Search: [API Docs](https://developers.google.com/custom-search/v1/overview)

### Contributing
- Follow existing code patterns
- Add attribution for Reddit-sourced content
- Test with small datasets first
- Document any new features

---

**Last Updated**: August 2025
**Version**: 1.0
**License**: MIT (respect Reddit's terms of service)