#!/usr/bin/env python3
"""
Search Reddit for Puerto Rico travel content using Google Custom Search API
"""

import json
import os
from googleapiclient.discovery import build

# Load environment variables
from dotenv import load_dotenv
import sys
import os

# Add parent directory to path and load .env
script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
env_path = os.path.join(parent_dir, '.env')
load_dotenv(env_path)

# Your API credentials from environment
API_KEY = os.getenv('GOOGLE_SEARCH_API_KEY')
SEARCH_ENGINE_ID = os.getenv('GOOGLE_SEARCH_ENGINE_ID')

# Puerto Rico Reddit searches - Recent content (2024+)
PUERTO_RICO_QUERIES = [
    "site:reddit.com puerto rico travel after:2024-01-01",
    "site:reddit.com puerto rico must visit after:2024-01-01", 
    "site:reddit.com puerto rico things to do after:2024-01-01"
]

def search_reddit_puerto_rico():
    """Search Reddit for Puerto Rico travel content"""
    # Debug: Check if credentials are loaded
    if not API_KEY:
        print("❌ Error: GOOGLE_SEARCH_API_KEY not found in environment")
        return None
    if not SEARCH_ENGINE_ID:
        print("❌ Error: GOOGLE_SEARCH_ENGINE_ID not found in environment")
        return None
    
    print(f"🔑 API Key loaded: {API_KEY[:20]}...")
    print(f"🆔 Search Engine ID: {SEARCH_ENGINE_ID}")
    print()
    
    try:
        # Build the service
        service = build("customsearch", "v1", developerKey=API_KEY)
        
        all_results = {}
        
        for query in PUERTO_RICO_QUERIES:
            print(f"🔍 Searching: {query}")
            
            # Perform search
            result = service.cse().list(
                q=query,
                cx=SEARCH_ENGINE_ID,
                num=10  # Get 10 results per query
            ).execute()
            
            # Extract and clean results
            items = result.get('items', [])
            search_info = result.get('searchInformation', {})
            
            cleaned_results = []
            for item in items:
                # Extract Reddit post info
                reddit_post = {
                    'title': item.get('title', '').replace(' - Reddit', ''),
                    'url': item.get('link', ''),
                    'snippet': item.get('snippet', ''),
                    'subreddit': extract_subreddit(item.get('link', '')),
                    'post_type': determine_post_type(item.get('title', ''))
                }
                cleaned_results.append(reddit_post)
            
            # Store results
            query_key = query.replace('site:reddit.com ', '').replace(' ', '_')
            all_results[query_key] = {
                'query': query,
                'total_results': search_info.get('totalResults', '0'),
                'search_time': search_info.get('searchTime', '0'),
                'posts': cleaned_results
            }
            
            # Print summary
            print(f"   📊 Found {len(cleaned_results)} posts")
            print(f"   ⏱️  Search time: {search_info.get('searchTime', 'Unknown')}s")
            print()
        
        # Save all results to JSON
        with open('puerto_rico_reddit_results_2024.json', 'w') as f:
            json.dump(all_results, f, indent=2)
        
        print("💾 Results saved to puerto_rico_reddit_results_2024.json")
        
        # Print summary
        print("\n" + "="*60)
        print("📋 PUERTO RICO REDDIT SEARCH SUMMARY")
        print("="*60)
        
        for query_key, data in all_results.items():
            print(f"\n🔍 {data['query']}")
            print(f"   📊 Total Results: {data['total_results']}")
            print(f"   📱 Posts Found: {len(data['posts'])}")
            
            # Show top 3 posts for each query
            for i, post in enumerate(data['posts'][:3], 1):
                print(f"   {i}. {post['title'][:80]}...")
                print(f"      r/{post['subreddit']} - {post['post_type']}")
        
        return all_results
        
    except Exception as e:
        print(f"❌ Error: {e}")
        if "API key not valid" in str(e):
            print("💡 Your API key seems to be working")
        elif "Custom search engine not found" in str(e):
            print("💡 You need to create a Custom Search Engine and add the CX ID")
            print("📝 Go to: https://programmablesearchengine.google.com/controlpanel/create")
        return None

def extract_subreddit(url):
    """Extract subreddit name from Reddit URL"""
    try:
        if '/r/' in url:
            return url.split('/r/')[1].split('/')[0]
        return 'unknown'
    except:
        return 'unknown'

def determine_post_type(title):
    """Determine if it's a question, recommendation, etc."""
    title_lower = title.lower()
    if any(word in title_lower for word in ['?', 'help', 'advice', 'recommend']):
        return 'Question'
    elif any(word in title_lower for word in ['guide', 'trip report', 'review']):
        return 'Guide/Review'
    elif any(word in title_lower for word in ['itinerary', 'planning']):
        return 'Itinerary'
    else:
        return 'Discussion'

if __name__ == "__main__":
    if SEARCH_ENGINE_ID == "YOUR_SEARCH_ENGINE_ID_HERE":
        print("⚠️  Please add your Custom Search Engine ID first!")
        print("📝 Go to: https://programmablesearchengine.google.com/controlpanel/create")
        print("🔧 Then replace YOUR_SEARCH_ENGINE_ID_HERE in this script")
    else:
        search_reddit_puerto_rico()