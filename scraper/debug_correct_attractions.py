#!/usr/bin/env python3
"""
Test the correct way to use c2e5695e939386e4 for attraction searches
Since it expects Typeahead_RequestInput, let's search for "Isla Verde attractions"
"""

import asyncio
import json
import httpx
import random
import string
from loguru import logger as log

async def search_attractions_correctly():
    """Use the typeahead query to search for attractions in Isla Verde"""
    
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
    
    # Test different search queries for attractions
    search_queries = [
        "Isla Verde attractions",
        "El Yunque",
        "Puerto Rico attractions",
        "Carolina Puerto Rico attractions",
        "Piñones",
        "Laguna Grande"
    ]
    
    url = "https://www.tripadvisor.com/data/graphql/ids"
    
    async with httpx.AsyncClient(http2=True, headers=headers, timeout=httpx.Timeout(30.0)) as client:
        
        for query in search_queries:
            print(f"\n{'='*60}")
            print(f"🔍 SEARCHING FOR: {query}")
            print(f"{'='*60}")
            
            # Use the same structure that worked for location search
            payload = [{
                "variables": {
                    "request": {
                        "query": query,
                        "limit": 10,
                        "scope": "WORLDWIDE",
                        "locale": "en-US", 
                        "scopeGeoId": 1,
                        "searchCenter": None,
                        "types": ["LOCATION"],
                        "locationTypes": [
                            "GEO", "AIRPORT", "ACCOMMODATION", "ATTRACTION",
                            "ATTRACTION_PRODUCT", "EATERY", "NEIGHBORHOOD",
                            "AIRLINE", "SHOPPING", "UNIVERSITY", "GENERAL_HOSPITAL",
                            "PORT", "FERRY", "CORPORATION", "VACATION_RENTAL",
                            "SHIP", "CRUISE_LINE", "CAR_RENTAL_OFFICE"
                        ],
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
                
                print(f"📊 Status Code: {response.status_code}")
                
                if response.status_code == 200:
                    try:
                        data = response.json()
                        
                        if isinstance(data, list) and len(data) > 0:
                            first_item = data[0]
                            
                            if "data" in first_item:
                                autocomplete = first_item["data"].get("Typeahead_autocomplete", {})
                                results = autocomplete.get("results", [])
                                
                                print(f"🎯 Found {len(results)} results:")
                                
                                for i, result in enumerate(results[:5], 1):
                                    name = result.get("text", "Unknown")
                                    place_type = result.get("details", {}).get("placeType", "Unknown")
                                    url = result.get("details", {}).get("url", "")
                                    coords = result.get("coordinates", {})
                                    
                                    print(f"   {i}. {name} ({place_type})")
                                    
                                    if coords:
                                        print(f"      📍 Coordinates: {coords.get('lat', 'N/A')}, {coords.get('lng', 'N/A')}")
                                    
                                    if url:
                                        print(f"      🔗 URL: {url}")
                                        
                                        # Check if this is an attraction
                                        if "Attraction" in url or "Activities" in url:
                                            print(f"      🎯 *** ATTRACTION FOUND ***")
                                    
                                    print()
                            
                    except json.JSONDecodeError as e:
                        print(f"❌ JSON decode error: {e}")
                        
                elif response.status_code == 403:
                    print("❌ 403 Forbidden")
                else:
                    print(f"❌ HTTP Error {response.status_code}")
                    print(f"Response: {response.text[:300]}...")
                    
            except Exception as e:
                print(f"❌ Request failed: {e}")
            
            await asyncio.sleep(2)
    
    print(f"\n{'='*60}")
    print("🏁 ATTRACTION SEARCH COMPLETED")
    print(f"{'='*60}")

if __name__ == "__main__":
    asyncio.run(search_attractions_correctly())