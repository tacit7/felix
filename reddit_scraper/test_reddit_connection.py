#!/usr/bin/env python3
"""
Simple Reddit API connection test
"""

import praw
import os
from dotenv import load_dotenv

load_dotenv()

def test_reddit_connection():
    print("🔧 Testing Reddit API connection...")
    
    # Initialize Reddit client
    reddit = praw.Reddit(
        client_id=os.getenv('REDDIT_CLIENT_ID'),
        client_secret=os.getenv('REDDIT_CLIENT_SECRET'),
        user_agent=os.getenv('REDDIT_USER_AGENT')
    )
    
    try:
        # Test 1: Basic connection
        print(f"✅ Reddit client initialized")
        print(f"📱 User agent: {reddit.config.user_agent}")
        
        # Test 2: Try to access a popular subreddit
        travel_sub = reddit.subreddit('travel')
        print(f"✅ Found r/travel: {travel_sub.display_name}")
        print(f"📊 Subscribers: {travel_sub.subscribers:,}")
        
        # Test 3: Try to get some hot posts
        print("\n🔥 Top 3 hot posts in r/travel:")
        for i, post in enumerate(travel_sub.hot(limit=3)):
            print(f"   {i+1}. {post.title[:60]}... ({post.score} upvotes)")
        
        # Test 4: Try a search
        print(f"\n🔍 Searching r/travel for 'Tokyo'...")
        search_results = travel_sub.search('Tokyo', limit=3, time_filter='month')
        tokyo_posts = list(search_results)
        
        if tokyo_posts:
            print(f"✅ Found {len(tokyo_posts)} Tokyo-related posts:")
            for post in tokyo_posts:
                print(f"   • {post.title[:50]}... ({post.score} upvotes)")
        else:
            print("⚠️ No Tokyo posts found in recent searches")
            
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = test_reddit_connection()
    print(f"\n{'✅ Connection test passed!' if success else '❌ Connection test failed!'}")