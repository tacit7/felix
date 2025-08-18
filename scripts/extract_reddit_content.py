#!/usr/bin/env python3
"""
Extract full Reddit post content using PRAW API from curated URLs
"""

import json
import os
import praw
from dotenv import load_dotenv
import sys
import time

# Load environment variables
script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
env_path = os.path.join(parent_dir, '.env')
load_dotenv(env_path)

# Reddit API credentials
REDDIT_CLIENT_ID = os.getenv('REDDIT_CLIENT_ID')
REDDIT_CLIENT_SECRET = os.getenv('REDDIT_CLIENT_SECRET')
REDDIT_USER_AGENT = os.getenv('REDDIT_USER_AGENT')

def extract_post_id_from_url(url):
    """Extract Reddit post ID from URL"""
    # URL format: https://www.reddit.com/r/subreddit/comments/POST_ID/title/
    try:
        parts = url.split('/')
        if 'comments' in parts:
            comment_index = parts.index('comments')
            if comment_index + 1 < len(parts):
                return parts[comment_index + 1]
    except:
        pass
    return None

def extract_full_reddit_content():
    """Extract full content from curated Reddit posts"""
    
    # Check credentials
    if not all([REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET, REDDIT_USER_AGENT]):
        print("❌ Error: Reddit API credentials not found in environment")
        print("📝 Please set up Reddit app and update .env file:")
        print("   REDDIT_CLIENT_ID=your_client_id")
        print("   REDDIT_CLIENT_SECRET=your_client_secret") 
        print("   REDDIT_USER_AGENT=AppName:v1.0 (by /u/yourusername)")
        return None
    
    # Initialize Reddit API
    try:
        reddit = praw.Reddit(
            client_id=REDDIT_CLIENT_ID,
            client_secret=REDDIT_CLIENT_SECRET,
            user_agent=REDDIT_USER_AGENT
        )
        
        # Test API connection
        print(f"🔑 Connected to Reddit API as: {reddit.user.me() or 'Anonymous'}")
        
    except Exception as e:
        print(f"❌ Error connecting to Reddit API: {e}")
        return None
    
    # Load curated posts
    try:
        with open('puerto_rico_reddit_curated_top20_2024.json', 'r') as f:
            curated_data = json.load(f)
    except FileNotFoundError:
        print("❌ Error: puerto_rico_reddit_curated_top20_2024.json not found")
        print("💡 Run filter_most_useful.py first to create curated posts")
        return None
    
    posts_with_content = []
    
    print(f"\n🔍 Extracting full content from {len(curated_data['top_posts'])} curated posts...")
    print("=" * 70)
    
    for i, post_data in enumerate(curated_data['top_posts'], 1):
        url = post_data['url']
        post_id = extract_post_id_from_url(url)
        
        if not post_id:
            print(f"{i}. ❌ Could not extract post ID from {url}")
            continue
            
        try:
            # Get full post content
            submission = reddit.submission(id=post_id)
            
            # Extract post details
            full_post = {
                'original_data': post_data,
                'reddit_content': {
                    'id': submission.id,
                    'title': submission.title,
                    'author': str(submission.author) if submission.author else '[deleted]',
                    'subreddit': str(submission.subreddit),
                    'created_utc': submission.created_utc,
                    'score': submission.score,
                    'upvote_ratio': submission.upvote_ratio,
                    'num_comments': submission.num_comments,
                    'selftext': submission.selftext,
                    'url': submission.url,
                    'permalink': f"https://reddit.com{submission.permalink}",
                    'is_self': submission.is_self
                },
                'top_comments': []
            }
            
            # Get top comments (up to 5)
            submission.comments.replace_more(limit=0)  # Remove "more comments"
            top_comments = submission.comments[:5]
            
            for comment in top_comments:
                if hasattr(comment, 'body') and comment.body != '[deleted]':
                    comment_data = {
                        'author': str(comment.author) if comment.author else '[deleted]',
                        'body': comment.body,
                        'score': comment.score,
                        'created_utc': comment.created_utc
                    }
                    full_post['top_comments'].append(comment_data)
            
            posts_with_content.append(full_post)
            
            print(f"{i}. ✅ {submission.title[:60]}...")
            print(f"   📊 Score: {submission.score} | Comments: {submission.num_comments}")
            print(f"   📝 Content: {len(submission.selftext)} chars | Top comments: {len(full_post['top_comments'])}")
            
            # Be respectful to Reddit API
            time.sleep(1)
            
        except Exception as e:
            print(f"{i}. ❌ Error extracting {url}: {e}")
    
    # Save full content
    output_data = {
        'meta': {
            'extracted_date': time.strftime('%Y-%m-%d %H:%M:%S'),
            'total_posts_extracted': len(posts_with_content),
            'reddit_api_used': True,
            'content_includes': ['full_post_text', 'top_comments', 'scores', 'metadata']
        },
        'posts_with_full_content': posts_with_content
    }
    
    with open('puerto_rico_reddit_top20_full_content.json', 'w') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n💾 Full Reddit content saved to puerto_rico_reddit_top20_full_content.json")
    print(f"📊 Successfully extracted {len(posts_with_content)} posts with full content")
    print(f"🎯 Ready for detailed content analysis and blog creation!")
    
    return output_data

if __name__ == "__main__":
    if 'your_client_id_here' in str(REDDIT_CLIENT_ID):
        print("⚠️  Please set up Reddit API credentials first!")
        print("📝 1. Go to: https://www.reddit.com/prefs/apps")
        print("📝 2. Create a 'script' app")  
        print("📝 3. Add credentials to .env file")
    else:
        extract_full_reddit_content()