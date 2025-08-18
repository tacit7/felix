#!/usr/bin/env python3
"""
Debug script to see what TripAdvisor's API is actually returning
"""

import asyncio
import json
import httpx
from loguru import logger as log

async def debug_tripadvisor_response():
    """Debug what TripAdvisor API is returning for location search"""
    
    # Same headers as the scraper
    base_headers = {
        "authority": "www.tripadvisor.com",
        "accept-language": "en-US,en;q=0.9",
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36",
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
        "accept-encoding": "gzip, deflate, br",
    }
    
    client = httpx.AsyncClient(
        http2=True,
        headers=base_headers,
        timeout=httpx.Timeout(30.0)
    )
    
    # Test queries
    test_queries = ["Dallas", "Dallas Texas", "Dallas, Texas", "Malta"]
    
    for query in test_queries:
        print(f"\n{'='*50}")
        print(f"Testing query: {query}")
        print(f"{'='*50}")
        
        try:
            # Use the same GraphQL payload as the scraper
            payload = [
                {
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
                                "SHIP", "CRUISE_LINE", "CAR_RENTAL_OFFICE",
                            ],
                            "userId": None,
                            "context": {},
                            "enabledFeatures": ["articles"],
                            "includeRecent": True,
                        }
                    },
                    "query": "c2e5695e939386e4",
                    "extensions": {"preRegisteredQueryId": "c2e5695e939386e4"},
                }
            ]
            
            headers = {
                "X-Requested-By": "a" * 180,  # Random request ID
                "Referer": "https://www.tripadvisor.com/Hotels",
                "Origin": "https://www.tripadvisor.com",
            }
            
            result = await client.post(
                url="https://www.tripadvisor.com/data/graphql/ids",
                json=payload,
                headers=headers,
            )
            
            print(f"Status Code: {result.status_code}")
            print(f"Response headers: {dict(result.headers)}")
            
            if result.status_code == 200:
                try:
                    data = json.loads(result.content)
                    print(f"Response structure:")
                    print(json.dumps(data, indent=2)[:1000] + "..." if len(str(data)) > 1000 else json.dumps(data, indent=2))
                    
                    # Try to navigate the structure
                    if isinstance(data, list) and len(data) > 0:
                        first_item = data[0]
                        print(f"\nFirst item keys: {first_item.keys() if isinstance(first_item, dict) else 'Not a dict'}")
                        
                        if "data" in first_item:
                            print(f"Data keys: {first_item['data'].keys()}")
                            
                            if "Typeahead_autocomplete" in first_item["data"]:
                                autocomplete = first_item["data"]["Typeahead_autocomplete"]
                                print(f"Autocomplete keys: {autocomplete.keys()}")
                                
                                if "results" in autocomplete:
                                    results = autocomplete["results"]
                                    print(f"Found {len(results)} results")
                                    
                                    if results:
                                        first_result = results[0]
                                        print(f"First result keys: {first_result.keys()}")
                                        print(f"First result: {json.dumps(first_result, indent=2)}")
                                        
                                        # Check if 'details' exists
                                        if "details" in first_result:
                                            print("✅ 'details' key found")
                                        else:
                                            print("❌ 'details' key NOT found")
                                            print("Available keys:", list(first_result.keys()))
                    
                except json.JSONDecodeError as e:
                    print(f"JSON decode error: {e}")
                    print(f"Raw response: {result.text[:500]}...")
                    
            else:
                print(f"HTTP Error: {result.status_code}")
                print(f"Response: {result.text[:500]}...")
                
        except Exception as e:
            print(f"Error: {e}")
    
    await client.aclose()

if __name__ == "__main__":
    asyncio.run(debug_tripadvisor_response())