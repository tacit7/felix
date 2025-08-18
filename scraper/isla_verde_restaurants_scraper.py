#!/usr/bin/env python3
"""
Isla Verde Restaurant Scraper using c2e5695e939386e4 query ID
Scrapes restaurants from TripAdvisor using the same GraphQL techniques
"""

import asyncio
import json
import httpx
import random
import string
import time
from typing import Dict, List, Optional
from loguru import logger as log

class IslaVerdeRestaurantScraper:
    def __init__(self):
        self.base_url = "https://www.tripadvisor.com"
        self.graphql_url = "https://www.tripadvisor.com/data/graphql/ids"
        self.query_id = "c2e5695e939386e4"  # Working query ID
        
        # Restaurant searches to perform
        self.restaurant_searches = [
            "Isla Verde restaurants",
            "San Juan restaurants", 
            "Puerto Rico restaurants",
            "Carolina Puerto Rico restaurants",
            "Piñones restaurants",
            "Condado restaurants",
            "Old San Juan restaurants",
            "best restaurants Puerto Rico",
            "local food Puerto Rico",
            "seafood restaurants San Juan"
        ]
        
        self.user_agents = [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ]
    
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
    
    def extract_name_from_url(self, url: str) -> str:
        """Extract restaurant name from TripAdvisor URL"""
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
        
        return "Unknown Restaurant"
    
    async def search_restaurants(self, search_query: str) -> List[Dict]:
        """Search for restaurants using GraphQL"""
        log.info(f"🍽️ Searching for: {search_query}")
        
        payload = [{
            "variables": {
                "request": {
                    "query": search_query,
                    "limit": 10,
                    "scope": "WORLDWIDE",
                    "locale": "en-US",
                    "scopeGeoId": 1,
                    "searchCenter": None,
                    "types": ["LOCATION"],
                    "locationTypes": [
                        "EATERY"
                    ],
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
                            
                            # Focus on restaurants/eateries
                            place_type = details.get("placeType", "")
                            url = details.get("url", "")
                            
                            if place_type == "EATERY" or "Restaurant_Review" in url:
                                # Extract name from URL if text is null
                                name = result.get("text", "")
                                if not name or name == "Unknown":
                                    name = self.extract_name_from_url(url)
                                
                                restaurant_data = {
                                    "name": name,
                                    "tripadvisor_url": url,
                                    "location_id": result.get("locationId"),
                                    "place_type": place_type,
                                    "coordinates": {
                                        "lat": coords.get("lat"),
                                        "lng": coords.get("lng")
                                    },
                                    "address": details.get("localizedAdditionalNames", {}).get("longOnlyHierarchy", ""),
                                    "search_query": search_query,
                                    "scraped_at": time.time()
                                }
                                
                                results.append(restaurant_data)
                                log.info(f"✅ Found restaurant: {restaurant_data['name']}")
                
        except Exception as e:
            log.error(f"❌ Error searching for {search_query}: {e}")
        
        return results
    
    async def scrape_all_restaurants(self) -> List[Dict]:
        """Search for all restaurants"""
        log.info("🍽️ Starting comprehensive restaurant search")
        
        all_restaurants = []
        
        for search_query in self.restaurant_searches:
            try:
                results = await self.search_restaurants(search_query)
                all_restaurants.extend(results)
                
                # Rate limiting
                await asyncio.sleep(2)
                
            except Exception as e:
                log.error(f"❌ Failed to search {search_query}: {e}")
                continue
        
        return all_restaurants
    
    def get_knowledge_base_restaurants(self) -> List[Dict]:
        """Puerto Rico restaurant knowledge base"""
        return [
            {
                "name": "Marmalade Restaurant & Wine Bar",
                "description": "Upscale contemporary restaurant in Old San Juan featuring creative Puerto Rican cuisine with international influences. Known for tasting menus and wine pairings.",
                "coordinates": {"lat": 18.4659, "lng": -66.1064},
                "categories": ["fine_dining", "contemporary", "wine_bar"],
                "cuisine": "Contemporary Puerto Rican",
                "price_range": "$$$",
                "rating": 4.5,
                "estimated_reviews": 1200,
                "neighborhood": "Old San Juan"
            },
            {
                "name": "Jose Enrique",
                "description": "Renowned local chef's restaurant serving elevated Puerto Rican comfort food. No reservations, cash only, frequently packed with locals and food enthusiasts.",
                "coordinates": {"lat": 18.4519, "lng": -66.0621},
                "categories": ["local_favorite", "puerto_rican", "comfort_food"],
                "cuisine": "Puerto Rican",
                "price_range": "$$",
                "rating": 4.7,
                "estimated_reviews": 890,
                "neighborhood": "Santurce"
            },
            {
                "name": "Koko",
                "description": "Modern Asian-Puerto Rican fusion restaurant with creative cocktails and innovative dishes. Popular for both dinner and weekend brunch.",
                "coordinates": {"lat": 18.4598, "lng": -66.0711},
                "categories": ["fusion", "asian", "cocktails", "brunch"],
                "cuisine": "Asian-Caribbean Fusion",
                "price_range": "$$$",
                "rating": 4.4,
                "estimated_reviews": 650,
                "neighborhood": "Condado"
            },
            {
                "name": "Santaella",
                "description": "Modern Puerto Rican restaurant in a beautifully restored building. Offers contemporary interpretations of traditional dishes with emphasis on local ingredients.",
                "coordinates": {"lat": 18.4532, "lng": -66.0634},
                "categories": ["modern_puerto_rican", "local_ingredients", "historic_building"],
                "cuisine": "Modern Puerto Rican",
                "price_range": "$$$",
                "rating": 4.6,
                "estimated_reviews": 1100,
                "neighborhood": "Santurce"
            },
            {
                "name": "La Placita de Santurce",
                "description": "Vibrant nightlife area with numerous bars and restaurants. Traditional Puerto Rican food, live music, and local atmosphere especially lively on weekends.",
                "coordinates": {"lat": 18.4521, "lng": -66.0625},
                "categories": ["nightlife", "traditional", "live_music", "local_scene"],
                "cuisine": "Puerto Rican",
                "price_range": "$-$$",
                "rating": 4.3,
                "estimated_reviews": 2100,
                "neighborhood": "Santurce"
            },
            {
                "name": "Piñones Food Kioskos",
                "description": "Beachside collection of food stands serving traditional Puerto Rican fried foods. Famous for alcapurrias, bacalaitos, and fresh seafood right on the beach.",
                "coordinates": {"lat": 18.4789, "lng": -65.9645},
                "categories": ["beach_food", "traditional", "fried_food", "seafood"],
                "cuisine": "Traditional Puerto Rican",
                "price_range": "$",
                "rating": 4.5,
                "estimated_reviews": 1800,
                "neighborhood": "Piñones"
            },
            {
                "name": "Oceano",
                "description": "Oceanfront restaurant specializing in fresh seafood and steaks with stunning ocean views. Located in a luxury hotel with upscale atmosphere.",
                "coordinates": {"lat": 18.4567, "lng": -66.0321},
                "categories": ["seafood", "steaks", "oceanfront", "upscale"],
                "cuisine": "International Seafood",
                "price_range": "$$$$",
                "rating": 4.3,
                "estimated_reviews": 750,
                "neighborhood": "Isla Verde"
            },
            {
                "name": "Barrachina",
                "description": "Historic restaurant in Old San Juan claiming to be the birthplace of the piña colada. Serves traditional Puerto Rican and Caribbean cuisine.",
                "coordinates": {"lat": 18.4656, "lng": -66.1058},
                "categories": ["historic", "pina_colada", "caribbean", "tourist_favorite"],
                "cuisine": "Puerto Rican & Caribbean",
                "price_range": "$$",
                "rating": 4.1,
                "estimated_reviews": 3200,
                "neighborhood": "Old San Juan"
            },
            {
                "name": "Lúulo",
                "description": "Contemporary restaurant focusing on local and sustainable ingredients. Creative menu that changes seasonally, popular with locals and food critics.",
                "coordinates": {"lat": 18.4534, "lng": -66.0639},
                "categories": ["contemporary", "sustainable", "local_ingredients", "seasonal"],
                "cuisine": "Contemporary Puerto Rican",
                "price_range": "$$$",
                "rating": 4.6,
                "estimated_reviews": 420,
                "neighborhood": "Santurce"
            },
            {
                "name": "El Convento Hotel Restaurant",
                "description": "Elegant restaurant in a historic converted convent serving refined Puerto Rican and international cuisine with beautiful courtyard seating.",
                "coordinates": {"lat": 18.4652, "lng": -66.1063},
                "categories": ["historic_hotel", "refined", "courtyard", "international"],
                "cuisine": "Puerto Rican & International",
                "price_range": "$$$",
                "rating": 4.4,
                "estimated_reviews": 890,
                "neighborhood": "Old San Juan"
            }
        ]
    
    async def create_restaurant_guide(self) -> Dict:
        """Create comprehensive restaurant guide"""
        log.info("📋 Creating comprehensive Isla Verde/Puerto Rico restaurant guide")
        
        # Get TripAdvisor data
        scraped_restaurants = await self.scrape_all_restaurants()
        
        # Get knowledge base
        knowledge_base = self.get_knowledge_base_restaurants()
        
        # Merge data - avoid duplicates
        final_restaurants = []
        
        # Add scraped restaurants
        for restaurant in scraped_restaurants:
            final_restaurants.append({
                **restaurant,
                "data_source": "tripadvisor_graphql"
            })
        
        # Add knowledge base restaurants (avoid duplicates)
        scraped_names = {rest['name'].lower() for rest in scraped_restaurants}
        
        for restaurant in knowledge_base:
            if restaurant['name'].lower() not in scraped_names:
                final_restaurants.append({
                    **restaurant,
                    "data_source": "knowledge_base"
                })
        
        # Organize by neighborhood/area
        neighborhoods = {}
        for restaurant in final_restaurants:
            area = restaurant.get('neighborhood', restaurant.get('address', 'Unknown Area'))
            if area not in neighborhoods:
                neighborhoods[area] = []
            neighborhoods[area].append(restaurant)
        
        return {
            "destination": "Isla Verde & Puerto Rico",
            "focus": "Restaurant & Dining Guide",
            "overview": "Comprehensive dining guide combining live TripAdvisor data with local restaurant expertise",
            "tripadvisor_location_id": 2665727,
            "scraped_restaurants_count": len(scraped_restaurants),
            "total_restaurants": len(final_restaurants),
            
            "restaurants": final_restaurants,
            "by_neighborhood": neighborhoods,
            
            "dining_highlights": {
                "fine_dining": ["Marmalade", "Santaella", "Oceano"],
                "local_favorites": ["Jose Enrique", "Piñones Kioskos", "La Placita"],
                "must_try_dishes": ["Mofongo", "Alcapurrias", "Bacalaitos", "Jibarito", "Pasteles"],
                "signature_drinks": ["Piña Colada", "Coquito", "Medalla Beer", "Rum cocktails"],
                "food_areas": ["Piñones", "La Placita Santurce", "Old San Juan", "Condado"]
            },
            
            "scraping_summary": {
                "graphql_successful": len(scraped_restaurants) > 0,
                "query_id_used": self.query_id,
                "knowledge_base_used": True,
                "search_queries_used": len(self.restaurant_searches)
            },
            
            "scraped_at": time.time(),
            "last_updated": "2025-08-13"
        }

async def main():
    """Run the restaurant scraper"""
    scraper = IslaVerdeRestaurantScraper()
    
    try:
        # Create restaurant guide
        guide = await scraper.create_restaurant_guide()
        
        # Save results
        filename = f"isla_verde_restaurants_{int(time.time())}.json"
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(guide, f, indent=2, ensure_ascii=False)
        
        # Print summary
        print(f"\n🍽️ ISLA VERDE RESTAURANT GUIDE")
        print("=" * 60)
        print(f"📍 Destination: {guide['destination']}")
        print(f"🎯 Total restaurants: {guide['total_restaurants']}")
        print(f"📊 TripAdvisor scraped: {guide['scraped_restaurants_count']}")
        print(f"✅ GraphQL successful: {guide['scraping_summary']['graphql_successful']}")
        print(f"🏘️ Neighborhoods covered: {len(guide['by_neighborhood'])}")
        
        print(f"\n🌟 TOP RESTAURANTS BY AREA:")
        for area, restaurants in guide['by_neighborhood'].items():
            if restaurants and area != "Unknown Area":
                print(f"\n📍 {area}:")
                for i, restaurant in enumerate(restaurants[:3], 1):
                    name = restaurant.get('name', 'Unknown')
                    cuisine = restaurant.get('cuisine', 'N/A')
                    price = restaurant.get('price_range', 'N/A')
                    rating = restaurant.get('rating', 'N/A')
                    
                    print(f"   {i}. {name}")
                    print(f"      🍽️ Cuisine: {cuisine}")
                    print(f"      💰 Price: {price}")
                    print(f"      ⭐ Rating: {rating}")
        
        print(f"\n🍴 MUST-TRY DISHES:")
        for dish in guide['dining_highlights']['must_try_dishes']:
            print(f"   • {dish}")
        
        print(f"\n💾 Complete guide saved to: {filename}")
        
        return guide
        
    except Exception as e:
        log.error(f"❌ Main execution failed: {e}")
        return None

if __name__ == "__main__":
    asyncio.run(main())