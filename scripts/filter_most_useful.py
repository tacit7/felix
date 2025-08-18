#!/usr/bin/env python3
"""
Filter the most useful Puerto Rico Reddit posts from 2024+ data
"""

import json
from datetime import datetime

def analyze_usefulness(post):
    """Score posts based on usefulness criteria"""
    score = 0
    title = post['title'].lower()
    snippet = post['snippet'].lower()
    
    # High value keywords
    high_value_keywords = [
        'must do', 'must visit', 'recommendations', 'suggestions', 'tips', 
        'honest review', 'best place', 'hidden gems', 'itinerary', 'guide'
    ]
    
    # Specific location mentions (adds local insight value)
    location_keywords = [
        'san juan', 'old san juan', 'condado', 'santurce', 'rincon', 
        'culebra', 'vieques', 'el yunque', 'ponce', 'isabela'
    ]
    
    # Practical information indicators
    practical_keywords = [
        'stay', 'hotel', 'restaurant', 'food', 'beach', 'safety', 
        'first time', 'planning', 'advice', 'experience'
    ]
    
    # Score based on title
    for keyword in high_value_keywords:
        if keyword in title:
            score += 10
    
    for keyword in location_keywords:
        if keyword in title or keyword in snippet:
            score += 5
    
    for keyword in practical_keywords:
        if keyword in title or keyword in snippet:
            score += 3
    
    # Bonus for recent posts (2024-2025)
    if any(year in post['snippet'] for year in ['2024', '2025']):
        score += 15
    
    # Bonus for comprehensive content (longer snippets usually mean more detail)
    if len(post['snippet']) > 200:
        score += 5
    
    # Post type bonuses
    if post['post_type'] == 'Guide/Review':
        score += 10
    elif post['post_type'] == 'Discussion':
        score += 7
    elif 'advice' in title or 'recommendations' in title:
        score += 8
    
    # Subreddit credibility
    if post['subreddit'] == 'PuertoRicoTravel':
        score += 5  # Specialized community
    
    return score

def filter_most_useful():
    """Filter and rank the most useful posts"""
    
    # Load the 2024+ results
    with open('puerto_rico_reddit_results_2024.json', 'r') as f:
        data = json.load(f)
    
    all_posts = []
    
    # Collect all posts from all queries
    for query_key, query_data in data.items():
        for post in query_data['posts']:
            post['source_query'] = query_key
            post['usefulness_score'] = analyze_usefulness(post)
            all_posts.append(post)
    
    # Remove duplicates (same URL)
    seen_urls = set()
    unique_posts = []
    for post in all_posts:
        if post['url'] not in seen_urls:
            seen_urls.add(post['url'])
            unique_posts.append(post)
    
    # Sort by usefulness score
    unique_posts.sort(key=lambda x: x['usefulness_score'], reverse=True)
    
    # Take top 20 most useful
    top_posts = unique_posts[:20]
    
    print("🎯 TOP 20 MOST USEFUL PUERTO RICO REDDIT POSTS (2024+)")
    print("=" * 70)
    
    for i, post in enumerate(top_posts, 1):
        print(f"\n{i}. {post['title'][:80]}...")
        print(f"   🔗 {post['url']}")
        print(f"   📊 Usefulness Score: {post['usefulness_score']}")
        print(f"   📱 Subreddit: r/{post['subreddit']}")
        print(f"   📝 Type: {post['post_type']}")
        print(f"   💡 Key Info: {post['snippet'][:150]}...")
        
        # Extract key insights
        snippet = post['snippet'].lower()
        insights = []
        
        if 'santurce' in snippet:
            insights.append("Santurce location info")
        if 'condado' in snippet:
            insights.append("Condado area details")
        if 'restaurant' in snippet:
            insights.append("Restaurant recommendations")
        if 'beach' in snippet:
            insights.append("Beach information")
        if 'safe' in snippet:
            insights.append("Safety insights")
        if 'first time' in snippet:
            insights.append("First-timer advice")
        
        if insights:
            print(f"   🎯 Contains: {', '.join(insights)}")
    
    # Save curated results
    curated_data = {
        'meta': {
            'filtered_date': datetime.now().isoformat(),
            'total_posts_analyzed': len(all_posts),
            'unique_posts': len(unique_posts),
            'top_posts_selected': len(top_posts),
            'filter_criteria': 'Usefulness score based on content quality, recency, and practical value'
        },
        'top_posts': top_posts
    }
    
    with open('puerto_rico_reddit_curated_top20_2024.json', 'w') as f:
        json.dump(curated_data, f, indent=2)
    
    print(f"\n💾 Curated results saved to puerto_rico_reddit_curated_top20_2024.json")
    print(f"📊 Analyzed {len(all_posts)} total posts, found {len(unique_posts)} unique posts")
    print(f"🎯 Selected top {len(top_posts)} most useful for travel planning")

if __name__ == "__main__":
    filter_most_useful()