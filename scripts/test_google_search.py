#!/usr/bin/env python3
"""
Test Google Custom Search API
Usage: python3 test_google_search.py "search query"
"""

import sys
import json
from googleapiclient.discovery import build

# Your API credentials
API_KEY = "AIzaSyBEdmgUfWse4Hzmycn5MiU4xJME9TBfdRc"
SEARCH_ENGINE_ID = "YOUR_SEARCH_ENGINE_ID_HERE"  # Replace with your CX ID

def test_search(query):
    """Test Google Custom Search API"""
    try:
        # Build the service
        service = build("customsearch", "v1", developerKey=API_KEY)
        
        # Perform search
        result = service.cse().list(
            q=query,
            cx=SEARCH_ENGINE_ID,
            num=5  # Number of results
        ).execute()
        
        # Extract results
        items = result.get('items', [])
        search_info = result.get('searchInformation', {})
        
        print(f"🔍 Search: {query}")
        print(f"📊 Total Results: {search_info.get('totalResults', 'Unknown')}")
        print(f"⏱️  Search Time: {search_info.get('searchTime', 'Unknown')}s")
        print("-" * 50)
        
        for i, item in enumerate(items, 1):
            print(f"{i}. {item.get('title', 'No title')}")
            print(f"   {item.get('link', 'No link')}")
            print(f"   {item.get('snippet', 'No snippet')[:100]}...")
            print()
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        if "API key not valid" in str(e):
            print("💡 Check your API key")
        elif "Custom search engine not found" in str(e):
            print("💡 Check your Search Engine ID (CX)")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 test_google_search.py 'search query'")
        sys.exit(1)
    
    query = " ".join(sys.argv[1:])
    test_search(query)