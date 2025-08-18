#!/usr/bin/env python3
"""
Reddit Travel Recommendations Scraper

Discovers what people like to do in cities and countries by analyzing
Reddit posts and comments from travel-related subreddits.

Usage:
    python reddit_travel_scraper.py --location "Austin, TX" --limit 50
    python reddit_travel_scraper.py --location "Puerto Rico" --subreddits "travel,solotravel"
"""

import praw
import json
import time
import argparse
import os
import re
from datetime import datetime, timezone
from dotenv import load_dotenv
from typing import List, Dict, Any, Optional

# Load environment variables
load_dotenv()

class RedditTravelScraper:
    def __init__(self):
        """Initialize Reddit API client"""
        self.reddit = praw.Reddit(
            client_id=os.getenv('REDDIT_CLIENT_ID'),
            client_secret=os.getenv('REDDIT_CLIENT_SECRET'),
            user_agent=os.getenv('REDDIT_USER_AGENT', 'RouteWise:v1.0 (by u/routewise)')
        )
        
        # Test authentication
        try:
            print(f"✅ Authenticated as: {self.reddit.user.me()}")
        except:
            print("✅ Reddit API connected (read-only mode)")
    
    def find_relevant_subreddits(self, location: str) -> List[str]:
        """Find subreddits related to a location"""
        location_clean = location.lower().replace(" ", "").replace(",", "")
        city_name = location.split(",")[0].strip().lower().replace(" ", "")
        
        # Common travel subreddits
        base_subreddits = [
            "travel", "solotravel", "backpacking", "digitalnomad",
            "earthporn", "traveltips", "TravelNoPics"
        ]
        
        # Location-specific subreddits to try
        location_subreddits = [
            city_name,
            location_clean,
            f"{city_name}travel",
            f"visit{city_name}",
        ]
        
        # US state/city patterns
        if "," in location:
            parts = [part.strip() for part in location.split(",")]
            if len(parts) == 2:
                city, state = parts
                state_abbr = self._get_state_abbreviation(state)
                if state_abbr:
                    location_subreddits.extend([
                        state_abbr.lower(),
                        f"{city.lower().replace(' ', '')}{state_abbr.lower()}",
                    ])
        
        return base_subreddits + location_subreddits
    
    def _get_state_abbreviation(self, state: str) -> Optional[str]:
        """Get US state abbreviation"""
        states = {
            "texas": "TX", "california": "CA", "florida": "FL",
            "new york": "NY", "illinois": "IL", "pennsylvania": "PA",
            "puerto rico": "PR", "hawaii": "HI", "alaska": "AK"
        }
        return states.get(state.lower())
    
    def search_travel_posts(self, location: str, subreddits: List[str], limit: int = 25) -> List[Dict]:
        """Search for posts about a location across multiple subreddits"""
        posts = []
        search_terms = self._generate_search_terms(location)
        
        print(f"🔍 Searching for '{location}' recommendations...")
        print(f"📍 Search terms: {', '.join(search_terms[:3])}...")
        print(f"🏛️  Subreddits: {', '.join(subreddits[:5])}...")
        
        for subreddit_name in subreddits:
            try:
                subreddit = self.reddit.subreddit(subreddit_name)
                
                # Search posts in this subreddit
                for search_term in search_terms:
                    try:
                        search_results = subreddit.search(
                            search_term,
                            limit=limit // len(search_terms),
                            time_filter='year',
                            sort='relevance'
                        )
                        
                        for post in search_results:
                            if self._is_relevant_post(post, location):
                                post_data = self._extract_post_data(post, location)
                                if post_data:
                                    posts.append(post_data)
                                    print(f"📝 Found: '{post.title[:50]}...' ({post.score} upvotes)")
                        
                        time.sleep(1)  # Rate limiting
                        
                    except Exception as e:
                        print(f"⚠️  Search error in r/{subreddit_name}: {e}")
                        continue
                        
            except Exception as e:
                print(f"⚠️  Subreddit r/{subreddit_name} not accessible: {e}")
                continue
        
        # Remove duplicates and sort by relevance
        unique_posts = {post['id']: post for post in posts}.values()
        sorted_posts = sorted(unique_posts, key=lambda x: x['score'], reverse=True)
        
        return sorted_posts[:limit]
    
    def _generate_search_terms(self, location: str) -> List[str]:
        """Generate search terms for a location"""
        city = location.split(",")[0].strip()
        
        terms = [
            f'"{location}"',  # Exact match
            f'"{city}"',      # City name
            f"{city} recommendations",
            f"{city} things to do",
            f"{city} travel guide",
            f"visiting {city}",
            f"{city} itinerary",
            f"best of {city}",
            f"{city} food",
            f"{city} attractions"
        ]
        
        return terms
    
    def _is_relevant_post(self, post, location: str) -> bool:
        """Check if post is relevant to the location"""
        location_keywords = location.lower().split()
        title_lower = post.title.lower()
        selftext_lower = (post.selftext or "").lower()
        
        # Check if location appears in title or content
        for keyword in location_keywords:
            if len(keyword) > 2 and (keyword in title_lower or keyword in selftext_lower):
                return True
        
        return False
    
    def _extract_post_data(self, post, location: str) -> Dict[str, Any]:
        """Extract relevant data from Reddit post"""
        try:
            # Get top comments with recommendations
            post.comments.replace_more(limit=3)
            comments = self._extract_recommendations_from_comments(
                post.comments.list(), location
            )
            
            return {
                'id': post.id,
                'title': post.title,
                'author': str(post.author) if post.author else '[deleted]',
                'score': post.score,
                'upvote_ratio': post.upvote_ratio,
                'num_comments': post.num_comments,
                'created_utc': post.created_utc,
                'url': f"https://reddit.com{post.permalink}",
                'selftext': post.selftext[:500] if post.selftext else None,
                'subreddit': str(post.subreddit),
                'location': location,
                'recommendations': comments,
                'scraped_at': datetime.now(timezone.utc).isoformat()
            }
        except Exception as e:
            print(f"⚠️  Error extracting post data: {e}")
            return None
    
    def _extract_recommendations_from_comments(self, comments: List, location: str, min_score: int = 2) -> List[Dict]:
        """Extract recommendations from post comments"""
        recommendations = []
        recommendation_keywords = [
            'recommend', 'must visit', 'check out', 'go to', 'try',
            'best', 'favorite', 'love', 'amazing', 'great',
            'restaurant', 'food', 'eat', 'bar', 'drink',
            'attraction', 'museum', 'park', 'beach', 'hiking'
        ]
        
        for comment in comments[:10]:  # Top 10 comments only
            if comment.score < min_score:
                continue
                
            comment_text = comment.body.lower()
            
            # Check if comment contains recommendations
            if any(keyword in comment_text for keyword in recommendation_keywords):
                # Extract potential place names (capitalized words/phrases)
                places = self._extract_place_names(comment.body)
                
                if places:
                    recommendations.append({
                        'comment_id': comment.id,
                        'author': str(comment.author) if comment.author else '[deleted]',
                        'score': comment.score,
                        'text': comment.body[:300],  # First 300 chars
                        'places': places,
                        'url': f"https://reddit.com{comment.permalink}"
                    })
        
        return recommendations
    
    def _extract_place_names(self, text: str) -> List[str]:
        """Extract potential place names from text"""
        # Simple regex to find capitalized words (potential place names)
        place_pattern = r'\b[A-Z][a-zA-Z\s&]+(?:Restaurant|Bar|Cafe|Museum|Park|Beach|Market|Street|Avenue|Plaza|Center|House|Building|Tower|Mall|Store)\b'
        places = re.findall(place_pattern, text)
        
        # Also look for quoted places or specific patterns
        quoted_places = re.findall(r'"([^"]*)"', text)
        
        # Clean and deduplicate
        all_places = places + [p for p in quoted_places if len(p) > 3]
        clean_places = list(set([p.strip() for p in all_places if len(p.strip()) > 3]))
        
        return clean_places[:5]  # Max 5 places per comment
    
    def save_results(self, posts: List[Dict], location: str, output_dir: str = "output") -> str:
        """Save results to JSON file"""
        os.makedirs(output_dir, exist_ok=True)
        
        timestamp = int(time.time())
        location_safe = re.sub(r'[^a-zA-Z0-9_-]', '_', location.lower())
        filename = f"{output_dir}/reddit_travel_{location_safe}_{timestamp}.json"
        
        output = {
            'location': location,
            'total_posts': len(posts),
            'scraped_at': datetime.now(timezone.utc).isoformat(),
            'posts': posts,
            'summary': self._generate_summary(posts)
        }
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        
        return filename
    
    def _generate_summary(self, posts: List[Dict]) -> Dict:
        """Generate summary of recommendations"""
        all_places = []
        subreddits = set()
        total_recommendations = 0
        
        for post in posts:
            subreddits.add(post['subreddit'])
            for rec in post['recommendations']:
                total_recommendations += 1
                all_places.extend(rec['places'])
        
        # Count place mentions
        place_counts = {}
        for place in all_places:
            place_counts[place] = place_counts.get(place, 0) + 1
        
        top_places = sorted(place_counts.items(), key=lambda x: x[1], reverse=True)[:10]
        
        return {
            'total_posts': len(posts),
            'total_recommendations': total_recommendations,
            'subreddits_found': list(subreddits),
            'top_mentioned_places': top_places,
            'avg_post_score': sum(p['score'] for p in posts) / len(posts) if posts else 0
        }

def main():
    parser = argparse.ArgumentParser(description='Scrape Reddit for travel recommendations')
    parser.add_argument('--location', required=True, help='Location to search for (e.g., "Austin, TX")')
    parser.add_argument('--subreddits', help='Comma-separated subreddits (default: auto-detect)')
    parser.add_argument('--limit', type=int, default=25, help='Max posts to find (default: 25)')
    parser.add_argument('--output', default='output', help='Output directory (default: output)')
    
    args = parser.parse_args()
    
    # Check environment variables
    if not os.getenv('REDDIT_CLIENT_ID'):
        print("❌ Missing REDDIT_CLIENT_ID environment variable")
        print("   Copy .env.example to .env and add your Reddit API credentials")
        return
    
    scraper = RedditTravelScraper()
    
    # Determine subreddits to search
    if args.subreddits:
        subreddits = [s.strip() for s in args.subreddits.split(',')]
    else:
        subreddits = scraper.find_relevant_subreddits(args.location)
    
    print(f"\n🚀 Starting Reddit travel recommendations scraper")
    print(f"📍 Location: {args.location}")
    print(f"🎯 Target posts: {args.limit}")
    print(f"🏛️  Subreddits: {len(subreddits)} subreddits\n")
    
    # Scrape posts
    posts = scraper.search_travel_posts(args.location, subreddits, args.limit)
    
    if not posts:
        print(f"\n❌ No travel recommendations found for '{args.location}'")
        print("   Try a different location or check subreddit accessibility")
        return
    
    # Save results
    filename = scraper.save_results(posts, args.location, args.output)
    
    # Print summary
    print(f"\n✅ Found {len(posts)} posts with travel recommendations!")
    print(f"📄 Results saved to: {filename}")
    
    # Show top recommendations
    total_recs = sum(len(p['recommendations']) for p in posts)
    print(f"💡 Total recommendations found: {total_recs}")
    
    if total_recs > 0:
        print(f"\n🏆 Top posts:")
        for post in posts[:3]:
            rec_count = len(post['recommendations'])
            print(f"   • {post['title'][:50]}... ({post['score']} upvotes, {rec_count} recs)")

if __name__ == "__main__":
    main()
