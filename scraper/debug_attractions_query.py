#!/usr/bin/env python3
"""
Debug script to test attraction queries with the correct query ID: c2e5695e939386e4
"""

import asyncio
import json
import httpx
import random
import string
from loguru import logger as log

async def debug_attractions_query():
    """Debug attractions GraphQL query with different payload structures"""
    
    location_id = "2665727"  # Isla Verde location ID we found
    query_id = "c2e5695e939386e4"  # Working query ID provided by user
    
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
    
    # Test different payload structures
    test_payloads = [
        # Structure 1: Basic attractions query
        [{
            "variables": {
                "locationId": int(location_id),
                "offset": 0,
                "limit": 15,
                "sort": "POPULARITY"
            },
            "query": query_id,
            "extensions": {"preRegisteredQueryId": query_id}
        }],
        
        # Structure 2: More detailed attractions query  
        [{
            "variables": {
                "locationId": int(location_id),
                "offset": 0,
                "limit": 15,
                "sort": "POPULARITY",
                "filters": [],
                "priceFilter": [],
                "categoryFilter": [],
                "subcategoryFilter": []
            },
            "query": query_id,
            "extensions": {"preRegisteredQueryId": query_id}
        }],
        
        # Structure 3: Similar to location search structure
        [{
            "variables": {
                "request": {
                    "locationId": int(location_id),
                    "limit": 15,
                    "offset": 0,
                    "sort": "POPULARITY",
                    "locale": "en-US"
                }
            },
            "query": query_id,
            "extensions": {"preRegisteredQueryId": query_id}
        }],
        
        # Structure 4: String location ID
        [{
            "variables": {
                "locationId": location_id,
                "offset": 0,
                "limit": 15
            },
            "query": query_id,
            "extensions": {"preRegisteredQueryId": query_id}
        }],
        
        # Structure 5: Minimal structure
        [{
            "variables": {
                "locationId": int(location_id)
            },
            "query": query_id,
            "extensions": {"preRegisteredQueryId": query_id}
        }]
    ]
    
    url = "https://www.tripadvisor.com/data/graphql/ids"
    
    async with httpx.AsyncClient(http2=True, headers=headers, timeout=httpx.Timeout(30.0)) as client:
        
        for i, payload in enumerate(test_payloads, 1):
            print(f"\n{'='*60}")
            print(f"🧪 TESTING PAYLOAD STRUCTURE {i}")
            print(f"{'='*60}")
            print(f"📋 Payload: {json.dumps(payload, indent=2)}")
            
            try:
                response = await client.post(url, json=payload)
                
                print(f"📊 Status Code: {response.status_code}")
                
                if response.status_code == 200:
                    try:
                        data = response.json()
                        
                        # Print response structure
                        print(f"📄 Response structure:")
                        print(json.dumps(data, indent=2)[:2000] + ("..." if len(str(data)) > 2000 else ""))
                        
                        # Try to find attractions in response
                        attractions_found = False
                        if isinstance(data, list) and len(data) > 0:
                            first_item = data[0]
                            
                            # Check for data key
                            if "data" in first_item:
                                data_section = first_item["data"]
                                print(f"🔍 Data section keys: {list(data_section.keys())}")
                                
                                # Look for any keys that might contain attractions
                                for key, value in data_section.items():
                                    if isinstance(value, dict):
                                        print(f"   📋 {key}: {list(value.keys())}")
                                        if any(attr in key.lower() for attr in ['attraction', 'activity', 'listing', 'item']):
                                            print(f"   🎯 Potential attractions data in '{key}'")
                                            attractions_found = True
                                    elif isinstance(value, list) and len(value) > 0:
                                        print(f"   📋 {key}: List with {len(value)} items")
                                        if any(attr in key.lower() for attr in ['attraction', 'activity', 'listing', 'item']):
                                            print(f"   🎯 Potential attractions list in '{key}'")
                                            attractions_found = True
                        
                        if attractions_found:
                            print("🎉 SUCCESS: Found potential attractions data!")
                        else:
                            print("⚠️ No obvious attractions data found")
                            
                    except json.JSONDecodeError as e:
                        print(f"❌ JSON decode error: {e}")
                        print(f"Raw response: {response.text[:500]}...")
                        
                elif response.status_code == 403:
                    print("❌ 403 Forbidden - Request blocked")
                else:
                    print(f"❌ HTTP Error {response.status_code}")
                    print(f"Response: {response.text[:500]}...")
                    
            except Exception as e:
                print(f"❌ Request failed: {e}")
            
            # Delay between requests
            await asyncio.sleep(2)
    
    print(f"\n{'='*60}")
    print("🏁 TESTING COMPLETED")
    print(f"{'='*60}")

if __name__ == "__main__":
    asyncio.run(debug_attractions_query())