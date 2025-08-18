#!/usr/bin/env python3
"""
Simple test to check if Puppeteer can bypass 403 errors
"""

import asyncio
from pyppeteer import launch
import time

async def test_tripadvisor_access():
    """Simple test to see if we can access TripAdvisor with Puppeteer"""
    
    print("🚀 Launching browser...")
    
    browser = await launch(
        headless=True,
        args=[
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--disable-blink-features=AutomationControlled',
            '--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        ]
    )
    
    page = await browser.newPage()
    await page.setViewport({'width': 1920, 'height': 1080})
    
    print("🌐 Testing TripAdvisor access...")
    
    try:
        # Test the same URL that was giving 403 errors
        test_url = "https://www.tripadvisor.com/Attraction_Review-g147320-d317041-Reviews-El_Yunque_National_Forest-Carolina_Puerto_Rico.html"
        
        response = await page.goto(test_url, {'waitUntil': 'networkidle2', 'timeout': 30000})
        
        print(f"✅ Response status: {response.status}")
        
        title = await page.title()
        print(f"📄 Page title: {title}")
        
        # Check if we got blocked
        if "403" in title or "Forbidden" in title:
            print("❌ Still getting blocked with Puppeteer")
        elif "El Yunque" in title:
            print("🎉 SUCCESS! Puppeteer bypassed the 403 error!")
            
            # Try to extract some basic content
            content = await page.evaluate('''
                () => {
                    const title = document.querySelector('h1');
                    const description = document.querySelector('[data-test-target*="description"]');
                    return {
                        title: title ? title.textContent.trim() : 'No title found',
                        description: description ? description.textContent.trim().substring(0, 200) : 'No description found',
                        url: window.location.href
                    };
                }
            ''')
            
            print(f"🎯 Extracted content:")
            print(f"   Title: {content['title']}")
            print(f"   Description: {content['description']}...")
            
        else:
            print(f"⚠️ Unexpected page content, title: {title}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        
    finally:
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_tripadvisor_access())