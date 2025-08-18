# Quick Reference - Reddit Content Pipeline

**Fast reference for daily operations**

## 🚀 Quick Start (3 commands)

```bash
# 1. Activate environment
source venv/bin/activate

# 2. Run complete pipeline
python3 reddit_puerto_rico_search.py && \
python3 filter_most_useful.py && \
python3 extract_reddit_content_batch.py

# 3. Check results
ls -la *puerto_rico*.json *puerto_rico*.md
```

## 📁 Key Files

| File | Purpose | Size |
|------|---------|------|
| `*_results_2024.json` | Raw search results | ~15KB |
| `*_curated_top20_2024.json` | Ranked posts | ~6KB |
| `*_batch_optimized.json` | Full extracted data | ~50KB |
| `*_top20_with_top3_comments.md` | Blog-ready content | ~14KB |

## 🔧 Quick Modifications

### Change Destination
```python
# In reddit_puerto_rico_search.py, line 26-30:
QUERIES = [
    "site:reddit.com [NEW_LOCATION] travel after:2024-01-01",
    "site:reddit.com [NEW_LOCATION] must visit after:2024-01-01", 
    "site:reddit.com [NEW_LOCATION] things to do after:2024-01-01"
]
```

### Adjust Results Count
```python
# In filter_most_useful.py, line 96:
top_posts = unique_posts[:20]  # Change 20 to desired number
```

### Change Date Range
```python
# In search queries, modify date:
"after:2024-01-01"  # Change to desired start date
```

## 📊 Performance Metrics

- **Total Time**: ~3 minutes
- **API Calls**: 4 total (3 Google + 1 Reddit)
- **Cost**: $0.00
- **Output**: 20 curated posts + 96 comments

## 🛡️ Compliance Checklist

- ✅ Free tier usage only
- ✅ Clear Reddit attribution
- ✅ No Reddit data in premium features
- ✅ Batch optimization for efficiency

## 🆘 Quick Fixes

**No results**: Check API keys in `.env`
**Rate limit**: Wait 1 minute, batch should prevent this
**Bad format**: Verify JSON output with `jq '.' filename.json`

## 📱 Daily Commands

```bash
# Check API usage
echo "Google searches today: 3/100"
echo "Reddit requests today: 1/144000" 

# View top posts
jq '.posts_with_full_content[0:3] | .[].reddit_content.title' *batch_optimized.json

# Count extracted content
jq '.meta.total_posts_extracted' *batch_optimized.json
```