#!/usr/bin/env python3
"""
TripAdvisor Scraper Runner
A simple script to run the TripAdvisor scraper with different configurations
"""

import asyncio
import json
import argparse
from datetime import datetime
from pathlib import Path

# Import your scraper classes
from tripadvisor_scraper import TripAdvisorScraper
# from tripadvisor_puppeteer import TripAdvisorPuppeteerScraper

async def run_httpx_scraper(location: str, content_type: str = "hotels", max_items: int = 5, max_review_pages: int = 2):
    """Run the HTTPX-based scraper for specified content type"""
    print(f"🔍 Starting HTTPX scraper for {content_type} in {location}")
    print(f"📊 Will scrape up to {max_items} {content_type} with {max_review_pages} review pages each")
    
    scraper = TripAdvisorScraper()
    
    try:
        # Run the appropriate workflow based on content type
        if content_type == "hotels":
            data = await scraper.scrape_hotels_from_search(
                query=location,
                max_hotels=max_items,
                max_review_pages_per_hotel=max_review_pages
            )
        elif content_type == "attractions":
            data = await scraper.scrape_attractions_from_search(
                query=location,
                max_attractions=max_items,
                max_review_pages_per_attraction=max_review_pages
            )
        elif content_type == "restaurants":
            data = await scraper.scrape_restaurants_from_search(
                query=location,
                max_restaurants=max_items,
                max_review_pages_per_restaurant=max_review_pages
            )
        else:
            print(f"❌ Unsupported content type: {content_type}")
            return []
        
        return data
        
    except Exception as e:
        print(f"❌ Error during scraping: {e}")
        return []
    finally:
        await scraper.close()

async def run_all_types_scraper(location: str, max_items_per_type: int = 3, max_review_pages: int = 1):
    """Run scraper for all content types (hotels, attractions, restaurants)"""
    print(f"🔍 Starting comprehensive scraper for {location}")
    print(f"📊 Will scrape up to {max_items_per_type} items per type with {max_review_pages} review pages each")
    
    scraper = TripAdvisorScraper()
    
    try:
        all_data = {}
        
        # Scrape hotels
        print("🏨 Scraping Hotels...")
        hotels_data = await scraper.scrape_hotels_from_search(
            query=location,
            max_hotels=max_items_per_type,
            max_review_pages_per_hotel=max_review_pages
        )
        all_data["hotels"] = hotels_data
        
        # Scrape attractions
        print("🎯 Scraping Attractions...")
        attractions_data = await scraper.scrape_attractions_from_search(
            query=location,
            max_attractions=max_items_per_type,
            max_review_pages_per_attraction=max_review_pages
        )
        all_data["attractions"] = attractions_data
        
        # Scrape restaurants
        print("🍽️ Scraping Restaurants...")
        restaurants_data = await scraper.scrape_restaurants_from_search(
            query=location,
            max_restaurants=max_items_per_type,
            max_review_pages_per_restaurant=max_review_pages
        )
        all_data["restaurants"] = restaurants_data
        
        return all_data
        
    except Exception as e:
        print(f"❌ Error during scraping: {e}")
        return {}
    finally:
        await scraper.close()

def save_results(data, location: str, content_type: str = "mixed", scraper_type: str = "httpx"):
    """Save results to JSON file with timestamp"""
    if not data:
        print("❌ No data to save")
        return None
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"tripadvisor_{location.lower().replace(' ', '_')}_{content_type}_{scraper_type}_{timestamp}.json"
    
    # Create results directory if it doesn't exist
    results_dir = Path("results")
    results_dir.mkdir(exist_ok=True)
    
    filepath = results_dir / filename
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"💾 Results saved to {filepath}")
    return filepath

def print_summary(data, content_type: str = "mixed"):
    """Print a summary of scraped data"""
    if not data:
        print("❌ No data to summarize")
        return
    
    print(f"\n📋 SCRAPING SUMMARY")
    print(f"=" * 50)
    
    if content_type == "all":
        # Handle mixed data structure
        total_items = 0
        total_reviews = 0
        
        for data_type, items in data.items():
            print(f"{data_type.capitalize()}: {len(items)} items")
            total_items += len(items)
            total_reviews += sum(len(item.get('reviews', [])) for item in items)
        
        print(f"Total items scraped: {total_items}")
        print(f"Total reviews collected: {total_reviews}")
        
        # Print details for each type
        for data_type, items in data.items():
            if items:
                print(f"\n🎯 {data_type.upper()}:")
                print("-" * 30)
                
                for i, item in enumerate(items, 1):
                    basic_data = item.get('basic_data', {})
                    preview = item.get('preview', {})
                    
                    name = basic_data.get('name') or preview.get('name', f'Unknown {data_type[:-1]}')
                    rating = basic_data.get('aggregateRating', {}).get('ratingValue', 'N/A')
                    review_count = len(item.get('reviews', []))
                    feature_count = len(item.get('features', []))
                    
                    print(f"{i}. {name}")
                    print(f"   ⭐ Rating: {rating}")
                    print(f"   💬 Reviews scraped: {review_count}")
                    print(f"   🏷️  Features: {feature_count}")
                    print()
    
    else:
        # Handle single content type
        if isinstance(data, list):
            items_data = data
        else:
            items_data = data.get(content_type, [])
        
        total_reviews = sum(len(item.get('reviews', [])) for item in items_data)
        total_features = sum(len(item.get('features', [])) for item in items_data)
        
        print(f"Total {content_type} scraped: {len(items_data)}")
        print(f"Total reviews collected: {total_reviews}")
        print(f"Total features collected: {total_features}")
        
        print(f"\n🎯 {content_type.upper()} FOUND:")
        print("-" * 30)
        
        for i, item in enumerate(items_data, 1):
            basic_data = item.get('basic_data', {})
            preview = item.get('preview', {})
            
            name = basic_data.get('name') or preview.get('name', f'Unknown {content_type[:-1]}')
            rating = basic_data.get('aggregateRating', {}).get('ratingValue', 'N/A')
            review_count = len(item.get('reviews', []))
            feature_count = len(item.get('features', []))
            
            print(f"{i}. {name}")
            print(f"   ⭐ Rating: {rating}")
            print(f"   💬 Reviews scraped: {review_count}")
            print(f"   🏷️  Features: {feature_count}")
            
            if item.get('description'):
                desc = item['description'][:100] + "..." if len(item['description']) > 100 else item['description']
                print(f"   📝 Description: {desc}")
            
            print()

async def main():
    """Main function with command line argument parsing"""
    parser = argparse.ArgumentParser(description='TripAdvisor Scraper for Hotels, Attractions & Restaurants')
    parser.add_argument('location', help='Location to search (e.g., "Malta", "New York")')
    parser.add_argument('--type', choices=['hotels', 'attractions', 'restaurants', 'all'], 
                       default='hotels', help='Content type to scrape (default: hotels)')
    parser.add_argument('--max-items', type=int, default=5, 
                       help='Maximum items to scrape per type (default: 5)')
    parser.add_argument('--max-review-pages', type=int, default=2, 
                       help='Maximum review pages per item (default: 2)')
    parser.add_argument('--scraper', choices=['httpx', 'puppeteer'], default='httpx', 
                       help='Scraper type to use (default: httpx)')
    parser.add_argument('--save', action='store_true', help='Save results to JSON file')
    parser.add_argument('--quiet', action='store_true', help='Minimal output')
    
    args = parser.parse_args()
    
    if not args.quiet:
        print("🕷️  TripAdvisor Multi-Content Scraper")
        print("=" * 45)
        print(f"📍 Location: {args.location}")
        print(f"🎯 Content type: {args.type}")
        print(f"📊 Max items per type: {args.max_items}")
        print(f"📄 Max review pages per item: {args.max_review_pages}")
        print(f"🔧 Scraper type: {args.scraper}")
        print()
    
    # Run the appropriate scraper
    if args.scraper == 'httpx':
        if args.type == 'all':
            data = await run_all_types_scraper(
                location=args.location,
                max_items_per_type=args.max_items,
                max_review_pages=args.max_review_pages
            )
        else:
            data = await run_httpx_scraper(
                location=args.location,
                content_type=args.type,
                max_items=args.max_items,
                max_review_pages=args.max_review_pages
            )
    elif args.scraper == 'puppeteer':
        print("🤖 Puppeteer scraper not implemented in this runner yet")
        print("💡 Use the standalone tripadvisor_puppeteer.py script")
        return
    
    # Save results if requested
    if args.save and data:
        save_results(data, args.location, args.type, args.scraper)
    
    # Print summary unless quiet mode
    if not args.quiet:
        print_summary(data, args.type)
    
    return data

# Quick test functions
async def quick_test():
    """Quick test with Malta - all content types"""
    print("🧪 Running quick test with Malta (all content types)...")
    data = await run_all_types_scraper("Malta", max_items_per_type=1, max_review_pages=1)
    print_summary(data, "all")
    return data

async def quick_test_hotels():
    """Quick test with Malta hotels only"""
    print("🧪 Running quick test with Malta hotels...")
    hotels = await run_httpx_scraper("Malta", "hotels", max_items=2, max_review_pages=1)
    print_summary(hotels, "hotels")
    return hotels

async def quick_test_attractions():
    """Quick test with Malta attractions only"""
    print("🧪 Running quick test with Malta attractions...")
    attractions = await run_httpx_scraper("Malta", "attractions", max_items=2, max_review_pages=1)
    print_summary(attractions, "attractions")
    return attractions

async def quick_test_restaurants():
    """Quick test with Malta restaurants only"""
    print("🧪 Running quick test with Malta restaurants...")
    restaurants = await run_httpx_scraper("Malta", "restaurants", max_items=2, max_review_pages=1)
    print_summary(restaurants, "restaurants")
    return restaurants

if __name__ == "__main__":
    # If no command line args provided, run quick test
    import sys
    if len(sys.argv) == 1:
        print("No arguments provided. Running quick test...")
        asyncio.run(quick_test())
    else:
        asyncio.run(main())

# Example usage:
# python scraper_runner.py "Malta" --type hotels --max-items 3 --save
# python scraper_runner.py "New York" --type attractions --max-items 5 --max-review-pages 3 --save
# python scraper_runner.py "Paris" --type restaurants --max-items 4 --save
# python scraper_runner.py "London" --type all --max-items 2 --save  # Scrape all types
# python scraper_runner.py "Tokyo" --scraper httpx --quiet
