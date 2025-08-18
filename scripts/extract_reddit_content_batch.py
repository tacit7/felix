#!/usr/bin/env python3
"""
Extract full Reddit post content using PRAW API - BATCH OPTIMIZED VERSION
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
    try:
        parts = url.split('/')
        if 'comments' in parts:
            comment_index = parts.index('comments')
            if comment_index + 1 < len(parts):
                return parts[comment_index + 1]
    except:
        pass
    return None

def extract_full_reddit_content_batch():
    """Extract full content from curated Reddit posts - BATCH OPTIMIZED"""
    
    # Check credentials
    if not all([REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET, REDDIT_USER_AGENT]):
        print("❌ Error: Reddit API credentials not found in environment")
        return None
    
    # Initialize Reddit API
    try:
        reddit = praw.Reddit(
            client_id=REDDIT_CLIENT_ID,
            client_secret=REDDIT_CLIENT_SECRET,
            user_agent=REDDIT_USER_AGENT
        )
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
        return None
    
    # Extract all post IDs first
    post_ids = []
    post_url_mapping = {}
    
    for post_data in curated_data['top_posts']:
        url = post_data['url']
        post_id = extract_post_id_from_url(url)
        if post_id:
            post_ids.append(post_id)
            post_url_mapping[post_id] = post_data
    
    print(f"\n🔍 Batch extracting content from {len(post_ids)} posts...")
    print("=" * 70)
    
    # BATCH REQUEST - Get all submissions at once
    fullnames = [f"t3_{post_id}" for post_id in post_ids]
    
    try:
        # Single API call for all submissions
        submissions = list(reddit.info(fullnames=fullnames))
        print(f"📦 Batch request successful: {len(submissions)} submissions retrieved")
        
    except Exception as e:
        print(f"❌ Batch request failed: {e}")
        print("🔄 Falling back to individual requests...")
        
        # Fallback to individual requests
        submissions = []
        for post_id in post_ids:
            try:
                submission = reddit.submission(id=post_id)
                submissions.append(submission)
            except Exception as e:
                print(f"❌ Failed to get {post_id}: {e}")
    
    posts_with_content = []
    
    # Process all submissions (already fetched)
    for i, submission in enumerate(submissions, 1):
        try:
            post_data = post_url_mapping.get(submission.id)
            if not post_data:
                continue
                
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
            
            # Get top comments (batch replace_more for efficiency)
            submission.comments.replace_more(limit=0)
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
            
        except Exception as e:
            print(f"{i}. ❌ Error processing submission: {e}")
    
    # Save full content
    output_data = {
        'meta': {
            'extracted_date': time.strftime('%Y-%m-%d %H:%M:%S'),
            'total_posts_extracted': len(posts_with_content),
            'reddit_api_used': True,
            'batch_optimized': True,
            'extraction_method': 'PRAW batch info() call',
            'content_includes': ['full_post_text', 'top_comments', 'scores', 'metadata']
        },
        'posts_with_full_content': posts_with_content
    }
    
    with open('puerto_rico_reddit_top20_batch_optimized.json', 'w') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n💾 Batch-optimized content saved to puerto_rico_reddit_top20_batch_optimized.json")
    print(f"📊 Successfully extracted {len(posts_with_content)} posts")
    print(f"⚡ Batch optimization: ~{len(post_ids)}x faster than individual requests")
    print(f"🎯 Ready for content analysis!")
    
    return output_data

if __name__ == "__main__":
    extract_full_reddit_content_batch()