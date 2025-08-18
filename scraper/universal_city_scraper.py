#!/usr/bin/env python3
"""
Universal City Scraper for TripAdvisor
Automatically scrapes any city's restaurants and attractions using GraphQL
Designed to integrate with Phoenix backend for on-demand data collection

Built using advanced techniques from: https://scrapfly.io/blog/posts/how-to-scrape-tripadvisor
Uses GraphQL query ID: c2e5695e939386e4 for bypassing anti-bot protection
"""

import asyncio
import json
import httpx
import random
import string
import time
import argparse
import sys
from typing import Dict, List, Optional
from loguru import logger as log

class UniversalCityScraper:
    def __init__(self, city_name: str, state_or_country: str = ""):
        self.city_name = city_name
        self.state_or_country = state_or_country
        self.location_query = f"{city_name} {state_or_country}".strip()
        
        self.base_url = "https://www.tripadvisor.com"
        self.graphql_url = "https://www.tripadvisor.com/data/graphql/ids"
        self.query_id = "c2e5695e939386e4"  # Universal working query ID
        
        # Generate dynamic search queries based on city
        self.restaurant_searches = self._generate_restaurant_searches()
        self.attraction_searches = self._generate_attraction_searches()
        
        self.user_agents = [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
        ]
    
    def _generate_restaurant_searches(self) -> List[str]:
        """Generate dynamic restaurant search queries for any city"""
        base_searches = [
            f"{self.city_name} restaurants",
            f"best restaurants {self.city_name}",
            f"top restaurants {self.city_name}",
            f"local food {self.city_name}",
            f"dining {self.city_name}",
        ]
        
        # Add state/country specific searches
        if self.state_or_country:
            base_searches.extend([
                f"restaurants {self.city_name} {self.state_or_country}",
                f"food {self.city_name} {self.state_or_country}",
            ])
        
        # Add common area modifiers
        area_modifiers = ["downtown", "center", "old town", "historic"]
        for modifier in area_modifiers:
            base_searches.append(f"{modifier} {self.city_name} restaurants")
        
        return base_searches
    
    def _generate_attraction_searches(self) -> List[str]:
        """Generate dynamic attraction search queries for any city"""
        base_searches = [
            f"things to do {self.city_name}",
            f"attractions {self.city_name}",
            f"sightseeing {self.city_name}",
            f"tourist attractions {self.city_name}",
            f"activities {self.city_name}",
        ]
        
        # Add state/country specific searches
        if self.state_or_country:
            base_searches.extend([
                f"things to do {self.city_name} {self.state_or_country}",
                f"attractions {self.city_name} {self.state_or_country}",
                f"visit {self.city_name} {self.state_or_country}",
            ])
        
        # Add common attraction types
        attraction_types = ["museums", "parks", "tours", "entertainment", "nightlife"]
        for attraction_type in attraction_types:
            base_searches.append(f"{attraction_type} {self.city_name}")
        
        return base_searches
    
    def generate_request_id(self, length=180):
        return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))
    
    def get_graphql_headers(self):
        return {
            "User-Agent": random.choice(self.user_agents),
            "Accept": "*/*",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Content-Type": "application/json",
            "X-Requested-By": self.generate_request_id(),
            "Referer": "https://www.tripadvisor.com/",
            "Origin": "https://www.tripadvisor.com",
            "Connection": "keep-alive",
            "Sec-Fetch-Dest": "empty",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Site": "same-origin"
        }
    
    def extract_name_from_url(self, url: str, content_type: str = "place") -> str:
        """Extract place name from TripAdvisor URL"""
        try:
            if "Reviews-" in url:
                # Extract from pattern: Reviews-Name-Location.html
                name_part = url.split("Reviews-")[1].split("-")[0]
                # Convert underscores to spaces and clean up
                name = name_part.replace("_", " ").replace("%20", " ")
                # Capitalize appropriately 
                name = " ".join(word.capitalize() for word in name.split())
                return name
        except Exception as e:
            log.error(f"Error extracting name from URL {url}: {e}")
        
        return f"Unknown {content_type.title()}"
    
    async def search_places(self, search_query: str, place_type: str = "EATERY") -> List[Dict]:
        """
        Search for places using GraphQL
        place_type: 'EATERY' for restaurants, 'ATTRACTION' for attractions
        """
        log.info(f"🔍 Searching for: {search_query} ({place_type})")
        
        payload = [{
            "variables": {
                "request": {
                    "query": search_query,
                    "limit": 15,  # Increased limit for better coverage
                    "scope": "WORLDWIDE",
                    "locale": "en-US",
                    "scopeGeoId": 1,
                    "searchCenter": None,
                    "types": ["LOCATION"],
                    "locationTypes": [place_type],
                    "userId": None,
                    "context": {},
                    "enabledFeatures": ["articles"],
                    "includeRecent": True
                }
            },
            "query": self.query_id,
            "extensions": {"preRegisteredQueryId": self.query_id}
        }]
        
        results = []
        
        try:
            async with httpx.AsyncClient(
                http2=True,
                headers=self.get_graphql_headers(),
                timeout=httpx.Timeout(30.0)
            ) as client:
                
                response = await client.post(self.graphql_url, json=payload)
                
                if response.status_code == 200:
                    data = response.json()
                    
                    if isinstance(data, list) and len(data) > 0:
                        autocomplete_data = data[0].get("data", {}).get("Typeahead_autocomplete", {})
                        search_results = autocomplete_data.get("results", [])
                        
                        for result in search_results:
                            details = result.get("details", {})
                            coords = result.get("coordinates", {})
                            
                            # Filter by place type
                            result_place_type = details.get("placeType", "")
                            url = details.get("url", "")
                            
                            type_matches = {
                                "EATERY": result_place_type == "EATERY" or "Restaurant_Review" in url,
                                "ATTRACTION": result_place_type == "ATTRACTION" or "Attraction_Review" in url
                            }
                            
                            if type_matches.get(place_type, False):
                                # Extract name from URL if text is null
                                name = result.get("text", "")
                                if not name or name == "Unknown":
                                    content_type = "restaurant" if place_type == "EATERY" else "attraction"
                                    name = self.extract_name_from_url(url, content_type)
                                
                                place_data = {
                                    "name": name,
                                    "tripadvisor_url": url,
                                    "location_id": result.get("locationId"),
                                    "place_type": result_place_type,
                                    "coordinates": {
                                        "lat": coords.get("lat"),
                                        "lng": coords.get("lng")
                                    },
                                    "address": details.get("localizedAdditionalNames", {}).get("longOnlyHierarchy", ""),
                                    "search_query": search_query,
                                    "scraped_at": time.time()
                                }
                                
                                results.append(place_data)
                                content_type = "🍽️" if place_type == "EATERY" else "🎯"
                                log.info(f"{content_type} Found: {place_data['name']}")
                
                elif response.status_code == 403:
                    log.warning(f"⚠️ 403 Forbidden for {search_query} - rate limited")
                else:
                    log.warning(f"⚠️ Status {response.status_code} for {search_query}")
                        
        except Exception as e:
            log.error(f"❌ Error searching for {search_query}: {e}")
        
        return results
    
    async def scrape_restaurants(self) -> List[Dict]:
        """Scrape all restaurants for the city"""
        log.info(f"🍽️ Scraping restaurants for {self.location_query}")
        
        all_restaurants = []
        seen_urls = set()  # Deduplicate by URL
        
        for search_query in self.restaurant_searches:
            try:
                results = await self.search_places(search_query, "EATERY")
                
                # Deduplicate results
                for result in results:
                    url = result.get("tripadvisor_url", "")
                    if url and url not in seen_urls:
                        seen_urls.add(url)
                        all_restaurants.append(result)
                
                # Rate limiting - crucial for avoiding blocks
                await asyncio.sleep(2.5)
                
            except Exception as e:
                log.error(f"❌ Failed to search {search_query}: {e}")
                continue
        
        log.info(f"✅ Found {len(all_restaurants)} unique restaurants")
        return all_restaurants
    
    async def scrape_attractions(self) -> List[Dict]:
        """Scrape all attractions for the city"""
        log.info(f"🎯 Scraping attractions for {self.location_query}")
        
        all_attractions = []
        seen_urls = set()  # Deduplicate by URL
        
        for search_query in self.attraction_searches:
            try:
                results = await self.search_places(search_query, "ATTRACTION")
                
                # Deduplicate results
                for result in results:
                    url = result.get("tripadvisor_url", "")
                    if url and url not in seen_urls:
                        seen_urls.add(url)
                        all_attractions.append(result)
                
                # Rate limiting
                await asyncio.sleep(2.5)
                
            except Exception as e:
                log.error(f"❌ Failed to search {search_query}: {e}")
                continue
        
        log.info(f"✅ Found {len(all_attractions)} unique attractions")
        return all_attractions
    
    async def scrape_all(self) -> Dict:
        """Scrape both restaurants and attractions for the city"""
        log.info(f"🚀 Starting comprehensive scraping for {self.location_query}")
        
        # Scrape both types
        restaurants = await self.scrape_restaurants()
        await asyncio.sleep(5)  # Longer break between content types
        attractions = await self.scrape_attractions()
        
        # Build comprehensive city data
        city_data = {
            "city": self.city_name,
            "state_or_country": self.state_or_country,
            "location_query": self.location_query,
            "scraped_at": time.time(),
            "last_updated": time.strftime("%Y-%m-%d", time.localtime()),
            
            # Summary stats
            "summary": {
                "total_restaurants": len(restaurants),
                "total_attractions": len(attractions),
                "total_places": len(restaurants) + len(attractions),
                "graphql_successful": len(restaurants) > 0 or len(attractions) > 0,
                "query_id_used": self.query_id
            },
            
            # Raw data
            "restaurants": restaurants,
            "attractions": attractions,
            
            # Organized by type for easy access
            "by_type": {
                "dining": restaurants,
                "sightseeing": attractions
            },
            
            # Metadata for Phoenix integration
            "scraping_metadata": {
                "restaurant_search_queries": self.restaurant_searches,
                "attraction_search_queries": self.attraction_searches,
                "rate_limit_delay": 2.5,
                "deduplication": "by_tripadvisor_url",
                "data_source": "tripadvisor_graphql"
            }
        }
        
        return city_data

def main():
    """Command line interface for the scraper"""
    parser = argparse.ArgumentParser(description="Universal TripAdvisor City Scraper")
    parser.add_argument("city", help="City name to scrape")
    parser.add_argument("--state", "-s", help="State or country (optional)", default="")
    parser.add_argument("--type", "-t", choices=["all", "restaurants", "attractions"], 
                       default="all", help="What to scrape")
    parser.add_argument("--output", "-o", help="Output filename (optional)")
    
    args = parser.parse_args()
    
    async def run_scraper():
        scraper = UniversalCityScraper(args.city, args.state)
        
        try:
            if args.type == "all":
                data = await scraper.scrape_all()
            elif args.type == "restaurants":
                restaurants = await scraper.scrape_restaurants()
                data = {
                    "city": args.city,
                    "type": "restaurants_only",
                    "restaurants": restaurants,
                    "total": len(restaurants),
                    "scraped_at": time.time()
                }
            elif args.type == "attractions":
                attractions = await scraper.scrape_attractions()
                data = {
                    "city": args.city,
                    "type": "attractions_only", 
                    "attractions": attractions,
                    "total": len(attractions),
                    "scraped_at": time.time()
                }
            
            # Save results
            if args.output:
                filename = args.output
            else:
                city_clean = args.city.lower().replace(" ", "_").replace(",", "")
                timestamp = int(time.time())
                filename = f"{city_clean}_tripadvisor_data_{timestamp}.json"
            
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            # Print summary
            print(f"\n🎯 SCRAPING COMPLETE: {args.city}")
            print("=" * 60)
            
            if args.type == "all":
                print(f"🍽️ Restaurants: {data['summary']['total_restaurants']}")
                print(f"🎯 Attractions: {data['summary']['total_attractions']}")
                print(f"📊 Total places: {data['summary']['total_places']}")
                print(f"✅ GraphQL successful: {data['summary']['graphql_successful']}")
            else:
                print(f"📊 Total found: {data['total']}")
            
            print(f"💾 Saved to: {filename}")
            
            return data
            
        except Exception as e:
            log.error(f"❌ Scraping failed: {e}")
            return None
    
    return asyncio.run(run_scraper())

if __name__ == "__main__":
    main()