# TripAdvisor Scraping Guide: Finding GraphQL Query IDs

**Complete guide to finding working GraphQL query IDs for TripAdvisor scraping**

*Built using techniques from: https://scrapfly.io/blog/posts/how-to-scrape-tripadvisor*

## Prerequisites

- Chrome browser
- Developer console access
- Basic understanding of GraphQL requests

## Step-by-Step Process

### 1. Open Chrome Developer Console
- Go to TripAdvisor.com
- Press `F12` or `Right Click → Inspect`
- Navigate to the **Network** tab

### 2. Set Up Network Filters
- Check the **XHR** filter (to show only AJAX requests)
- In the **text filter box**, type: `ids`
- This filters requests to show only GraphQL endpoint calls

### 3. Trigger Search Queries
Perform searches based on what you want to scrape:

**For Restaurants:**
- Type "restaurants" in TripAdvisor search
- Or search for specific restaurant names
- Example: "San Juan restaurants" or "Marmalade restaurant"

**For Attractions/Things to Do:**
- Type "things to do" in TripAdvisor search  
- Or search for specific attractions
- Example: "things to do San Juan" or "El Yunque"

**For Hotels:**
- Type hotel names or "hotels [location]"
- Example: "hotels San Juan"

### 4. Analyze Network Requests
- Look for requests to `/data/graphql/ids`
- Each request will show a **query ID** in the request payload
- Click on individual requests to inspect:
  - **Headers** tab: Shows request headers
  - **Request** tab: Shows the GraphQL payload
  - **Response** tab: Shows what data TripAdvisor returned

### 5. Extract Working Query IDs
Look through the GraphQL requests to find:
- **Query ID**: Found in `extensions.preRegisteredQueryId`
- **Response data**: Check if the response contains the data you want
- **Request structure**: Note the variables and parameters used

## Current Working Query IDs

Based on our testing, here are confirmed working query IDs:

### Universal Search Query: `c2e5695e939386e4`
**Works for:** Location searches, attractions, restaurants
**Location Types:**
- `["ATTRACTION"]` - For attractions/things to do
- `["EATERY"]` - For restaurants only
- `["ACCOMMODATION"]` - For hotels
- `["GEO", "ATTRACTION", "EATERY"]` - Mixed results

**Request Structure:**
```json
{
  "variables": {
    "request": {
      "query": "search term",
      "limit": 10,
      "scope": "WORLDWIDE", 
      "locale": "en-US",
      "scopeGeoId": 1,
      "searchCenter": null,
      "types": ["LOCATION"],
      "locationTypes": ["EATERY"], // or ["ATTRACTION"]
      "userId": null,
      "context": {},
      "enabledFeatures": ["articles"],
      "includeRecent": true
    }
  },
  "query": "c2e5695e939386e4",
  "extensions": {"preRegisteredQueryId": "c2e5695e939386e4"}
}
```

## Anti-Bot Headers (Required)

```javascript
const headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Content-Type": "application/json",
    "X-Requested-By": generateRandomString(180), // Random 180-char string
    "Referer": "https://www.tripadvisor.com/",
    "Origin": "https://www.tripadvisor.com",
    "Connection": "keep-alive",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors", 
    "Sec-Fetch-Site": "same-origin"
}
```

## Practical Examples

### Example 1: Finding Restaurant Query ID
1. Go to TripAdvisor.com
2. Open Developer Console → Network → XHR filter → type "ids"
3. Search for "restaurants San Juan"
4. Look for `/data/graphql/ids` requests
5. Find request with restaurant results in response
6. Extract the query ID from `extensions.preRegisteredQueryId`

### Example 2: Finding Attractions Query ID  
1. Search for "things to do El Yunque"
2. Filter network requests by "ids"
3. Find GraphQL request with attraction data
4. Note the query ID and request parameters

### Example 3: Testing Query ID
```python
# Test the found query ID
payload = [{
    "variables": {
        "request": {
            "query": "restaurants Isla Verde",
            "limit": 5,
            "scope": "WORLDWIDE",
            "locale": "en-US", 
            "scopeGeoId": 1,
            "locationTypes": ["EATERY"]
        }
    },
    "query": "YOUR_FOUND_QUERY_ID",
    "extensions": {"preRegisteredQueryId": "YOUR_FOUND_QUERY_ID"}
}]
```

## Troubleshooting

### Query ID Not Working
- **Problem**: Getting empty results or errors
- **Solution**: Double-check the request structure matches exactly
- **Check**: locationTypes array, variable names, required fields

### 403 Forbidden Errors
- **Problem**: Requests getting blocked
- **Solution**: Ensure proper headers including `X-Requested-By` random string
- **Rate Limit**: Add 2-second delays between requests

### Empty Results  
- **Problem**: Query returns no data
- **Solution**: Try different locationTypes combinations
- **For restaurants**: Use only `["EATERY"]`  
- **For attractions**: Use only `["ATTRACTION"]`

### Names Showing as "Unknown"
- **Problem**: API returns null for text field
- **Solution**: Extract names from the URL path
- **Pattern**: `/Restaurant_Review-g123-d456-Reviews-Restaurant_Name-Location.html`

## Success Metrics

Our implementation successfully:
- ✅ **Bypassed 403 errors** using proper headers
- ✅ **Found 30+ attractions** with real TripAdvisor URLs
- ✅ **Found 18+ restaurants** with location IDs  
- ✅ **Extracted coordinates** and address data
- ✅ **Rate limited properly** to avoid blocking

## Query ID Rotation Strategy

Since query IDs can expire:
1. **Monitor for failures** (empty results, 400 errors)
2. **Re-run the discovery process** using Chrome console
3. **Update query IDs** in your scraper
4. **Test with multiple IDs** as fallbacks

## Legal & Ethical Considerations

- ✅ **Respect robots.txt** and rate limits
- ✅ **Don't collect personal data** (reviews, user info)
- ✅ **Use data responsibly** for legitimate business purposes
- ✅ **Cache results** to minimize requests
- ❌ **Avoid excessive scraping** that could impact site performance

---

**This process gives us the ability to scrape TripAdvisor's attractions, restaurants, and hotels data reliably while bypassing their anti-bot protections.** 🎯