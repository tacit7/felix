#!/usr/bin/env python3
"""
Debug restaurant searches to see what TripAdvisor returns
"""

import asyncio
import json
import httpx
import random
import string
from loguru import logger as log

async def debug_restaurant_searches():
    """Debug what we get when searching for restaurants"""
    
    query_id = "c2e5695e939386e4"
    
    def generate_request_id(length=180):
        return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Content-Type": "application/json",
        "X-Requested-By": generate_request_id(),
        "Referer": "https://www.tripadvisor.com/",
        "Origin": "https://www.tripadvisor.com",
        "Connection": "keep-alive",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Site": "same-origin"
    }
    
    # Test specific restaurant searches
    test_searches = [
        "Jose Enrique San Juan",
        "Marmalade Restaurant Puerto Rico", 
        "Santaella restaurant",
        "restaurants Isla Verde",
        "Barrachina Old San Juan"
    ]
    
    url = "https://www.tripadvisor.com/data/graphql/ids"
    
    async with httpx.AsyncClient(http2=True, headers=headers, timeout=httpx.Timeout(30.0)) as client:
        
        for search_term in test_searches:
            print(f"\n{'='*60}")
            print(f"🔍 SEARCHING FOR: {search_term}")
            print(f"{'='*60}")
            
            # Try different location type combinations
            location_type_sets = [
                # Restaurants only
                ["EATERY", "RESTAURANT"],
                # Restaurants + attractions
                ["EATERY", "RESTAURANT", "ATTRACTION"],
                # All types
                ["GEO", "AIRPORT", "ACCOMMODATION", "ATTRACTION", "EATERY", "RESTAURANT", "NEIGHBORHOOD"],
                # Minimal
                ["EATERY"]
            ]
            
            for i, location_types in enumerate(location_type_sets, 1):
                print(f"\n--- Test {i}: Location types {location_types} ---")
                
                payload = [{
                    "variables": {
                        "request": {
                            "query": search_term,
                            "limit": 5,
                            "scope": "WORLDWIDE",
                            "locale": "en-US",
                            "scopeGeoId": 1,
                            "searchCenter": None,
                            "types": ["LOCATION"],
                            "locationTypes": location_types,
                            "userId": None,
                            "context": {},
                            "enabledFeatures": ["articles"],
                            "includeRecent": True
                        }
                    },
                    "query": query_id,
                    "extensions": {"preRegisteredQueryId": query_id}
                }]
                
                try:
                    response = await client.post(url, json=payload)
                    
                    if response.status_code == 200:
                        data = response.json()
                        
                        if isinstance(data, list) and len(data) > 0:
                            autocomplete_data = data[0].get("data", {}).get("Typeahead_autocomplete", {})
                            results = autocomplete_data.get("results", [])
                            
                            print(f"📊 Found {len(results)} results:")
                            
                            for j, result in enumerate(results, 1):
                                name = result.get("text", "Unknown")
                                details = result.get("details", {})
                                place_type = details.get("placeType", "Unknown")
                                url_path = details.get("url", "")
                                
                                print(f"   {j}. {name} ({place_type})")
                                
                                if url_path:
                                    print(f"      🔗 {url_path[:60]}...")
                                    
                                    # Check what type of URL this is
                                    if "Restaurant_Review" in url_path:
                                        print(f"      🍽️ *** RESTAURANT URL ***")
                                    elif "Attraction_Review" in url_path:
                                        print(f"      🎯 Attraction URL")
                                    elif "Hotel_Review" in url_path:
                                        print(f"      🏨 Hotel URL")
                                
                                coords = result.get("coordinates", {})
                                if coords.get("lat"):
                                    print(f"      📍 Coordinates: {coords.get('lat')}, {coords.get('lng')}")
                                
                                print()
                    else:
                        print(f"❌ Status {response.status_code}")
                        
                except Exception as e:
                    print(f"❌ Error: {e}")
                
                await asyncio.sleep(1)
            
            await asyncio.sleep(2)  # Between search terms

if __name__ == "__main__":
    asyncio.run(debug_restaurant_searches())