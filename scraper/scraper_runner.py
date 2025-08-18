#!/usr/bin/env python3
"""
Scraper Runner - Quick interface for running TripAdvisor scrapes
Usage:
  python3 scraper_runner.py "Austin, TX"
  python3 scraper_runner.py "Miami, FL" --restaurants-only
  python3 scraper_runner.py "Portland" --attractions-only
  python3 scraper_runner.py "New York" --quick
"""

import asyncio
import sys
import argparse
from universal_city_scraper import UniversalCityScraper
import json
import time

def parse_location(location_str):
    """Parse 'City, State' or 'City' format"""
    parts = [part.strip() for part in location_str.split(',')]
    if len(parts) >= 2:
        return parts[0], parts[1]
    else:
        return parts[0], ""

async def quick_scrape(city, state="", content_type="all"):
    """Quick scrape with minimal search queries for fast results"""
    scraper = UniversalCityScraper(city, state)
    
    # Reduce search queries for speed
    if content_type in ["all", "restaurants"]:
        scraper.restaurant_searches = [
            f"{city} restaurants",
            f"best restaurants {city}",
            f"dining {city}"
        ]
    
    if content_type in ["all", "attractions"]:
        scraper.attraction_searches = [
            f"things to do {city}",
            f"attractions {city}",
            f"sightseeing {city}"
        ]
    
    if content_type == "all":
        return await scraper.scrape_all()
    elif content_type == "restaurants":
        restaurants = await scraper.scrape_restaurants()
        return {
            "city": city,
            "type": "restaurants_only",
            "restaurants": restaurants,
            "total": len(restaurants),
            "scraped_at": time.time()
        }
    elif content_type == "attractions":
        attractions = await scraper.scrape_attractions()
        return {
            "city": city,
            "type": "attractions_only",
            "attractions": attractions,
            "total": len(attractions),
            "scraped_at": time.time()
        }

def main():
    parser = argparse.ArgumentParser(description="TripAdvisor Scraper Runner")
    parser.add_argument("location", help="City name (e.g., 'Austin, TX' or 'Portland')")
    parser.add_argument("--restaurants-only", action="store_true", help="Scrape only restaurants")
    parser.add_argument("--attractions-only", action="store_true", help="Scrape only attractions")
    parser.add_argument("--quick", action="store_true", help="Quick scrape with fewer queries")
    parser.add_argument("--output", "-o", help="Custom output filename")
    
    args = parser.parse_args()
    
    # Parse location
    city, state = parse_location(args.location)
    
    # Determine content type
    if args.restaurants_only:
        content_type = "restaurants"
    elif args.attractions_only:
        content_type = "attractions"
    else:
        content_type = "all"
    
    print(f"🚀 Starting scrape for: {city}" + (f", {state}" if state else ""))
    print(f"📊 Content type: {content_type}")
    print(f"⚡ Quick mode: {'Yes' if args.quick else 'No'}")
    print("=" * 50)
    
    async def run():
        if args.quick:
            data = await quick_scrape(city, state, content_type)
        else:
            scraper = UniversalCityScraper(city, state)
            
            if content_type == "all":
                data = await scraper.scrape_all()
            elif content_type == "restaurants":
                restaurants = await scraper.scrape_restaurants()
                data = {
                    "city": city,
                    "type": "restaurants_only",
                    "restaurants": restaurants,
                    "total": len(restaurants),
                    "scraped_at": time.time()
                }
            elif content_type == "attractions":
                attractions = await scraper.scrape_attractions()
                data = {
                    "city": city,
                    "type": "attractions_only",
                    "attractions": attractions,
                    "total": len(attractions),
                    "scraped_at": time.time()
                }
        
        # Generate filename
        if args.output:
            filename = args.output
        else:
            city_clean = city.lower().replace(" ", "_").replace(",", "")
            timestamp = int(time.time())
            mode = "quick_" if args.quick else ""
            filename = f"{city_clean}_{mode}{content_type}_{timestamp}.json"
        
        # Save results
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        # Print results
        print(f"\n✅ SCRAPING COMPLETE!")
        print("=" * 50)
        
        if content_type == "all":
            restaurants = data.get("summary", {}).get("total_restaurants", 0)
            attractions = data.get("summary", {}).get("total_attractions", 0) 
            print(f"🍽️ Restaurants found: {restaurants}")
            print(f"🎯 Attractions found: {attractions}")
            print(f"📊 Total places: {restaurants + attractions}")
        else:
            total = data.get("total", 0)
            emoji = "🍽️" if content_type == "restaurants" else "🎯"
            print(f"{emoji} {content_type.title()} found: {total}")
        
        print(f"💾 Saved to: {filename}")
        
        # Show sample results
        if content_type == "all":
            sample_restaurants = data.get("restaurants", [])[:3]
            sample_attractions = data.get("attractions", [])[:3]
            
            if sample_restaurants:
                print(f"\n🍽️ Sample restaurants:")
                for i, place in enumerate(sample_restaurants, 1):
                    print(f"  {i}. {place.get('name', 'Unknown')}")
            
            if sample_attractions:
                print(f"\n🎯 Sample attractions:")
                for i, place in enumerate(sample_attractions, 1):
                    print(f"  {i}. {place.get('name', 'Unknown')}")
        
        elif content_type == "restaurants":
            sample = data.get("restaurants", [])[:5]
            if sample:
                print(f"\n🍽️ Found restaurants:")
                for i, place in enumerate(sample, 1):
                    print(f"  {i}. {place.get('name', 'Unknown')}")
        
        elif content_type == "attractions":
            sample = data.get("attractions", [])[:5]
            if sample:
                print(f"\n🎯 Found attractions:")
                for i, place in enumerate(sample, 1):
                    print(f"  {i}. {place.get('name', 'Unknown')}")
        
        return data
    
    try:
        result = asyncio.run(run())
        return result
    except KeyboardInterrupt:
        print("\n❌ Scraping interrupted by user")
        return None
    except Exception as e:
        print(f"\n❌ Scraping failed: {e}")
        return None

if __name__ == "__main__":
    main()