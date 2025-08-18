import asyncio
import json
import math
import random
import string
from typing import List, Dict, Optional, TypedDict
from urllib.parse import urljoin
import httpx
from parsel import Selector
from loguru import logger as log

class LocationData(TypedDict):
    """Result dataclass for TripAdvisor location data"""
    localizedName: str
    url: str
    HOTELS_URL: str
    ATTRACTIONS_URL: str
    RESTAURANTS_URL: str
    placeType: str
    latitude: float
    longitude: float

class Preview(TypedDict):
    """Hotel preview from search results"""
    url: str
    name: str

class TripAdvisorScraper:
    def __init__(self):
        # Headers that mimic Chrome browser on Windows
        self.base_headers = {
            "authority": "www.tripadvisor.com",
            "accept-language": "en-US,en;q=0.9",
            "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36",
            "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
            "accept-encoding": "gzip, deflate, br",
        }
        
        # Initialize HTTP client with HTTP2 support
        self.client = httpx.AsyncClient(
            http2=True,  # HTTP2 connections are less likely to get blocked
            headers=self.base_headers,
            timeout=httpx.Timeout(150.0),
            limits=httpx.Limits(max_connections=5),
        )

    async def scrape_location_data(self, query: str) -> List[LocationData]:
        """
        Scrape search location data from a given query.
        e.g. "New York" will return TripAdvisor's location details for this query
        """
        log.info(f"Scraping location data: {query}")
        
        # The GraphQL payload that defines our search
        payload = [
            {
                "variables": {
                    "request": {
                        "query": query,
                        "limit": 10,
                        "scope": "WORLDWIDE",
                        "locale": "en-US",
                        "scopeGeoId": 1,
                        "searchCenter": None,
                        "types": ["LOCATION"],
                        "locationTypes": [
                            "GEO", "AIRPORT", "ACCOMMODATION", "ATTRACTION",
                            "ATTRACTION_PRODUCT", "EATERY", "NEIGHBORHOOD",
                            "AIRLINE", "SHOPPING", "UNIVERSITY", "GENERAL_HOSPITAL",
                            "PORT", "FERRY", "CORPORATION", "VACATION_RENTAL",
                            "SHIP", "CRUISE_LINE", "CAR_RENTAL_OFFICE",
                        ],
                        "userId": None,
                        "context": {},
                        "enabledFeatures": ["articles"],
                        "includeRecent": True,
                    }
                },
                "query": "c2e5695e939386e4",
                "extensions": {"preRegisteredQueryId": "c2e5695e939386e4"},
            }
        ]
        
        # Generate a random request ID for this request to succeed
        random_request_id = "".join(
            random.choice(string.ascii_lowercase + string.digits) for i in range(180)
        )
        
        headers = {
            "X-Requested-By": random_request_id,
            "Referer": "https://www.tripadvisor.com/Hotels",
            "Origin": "https://www.tripadvisor.com",
        }
        
        try:
            result = await self.client.post(
                url="https://www.tripadvisor.com/data/graphql/ids",
                json=payload,
                headers=headers,
            )
            result.raise_for_status()
            
            data = json.loads(result.content)
            results = data[0]["data"]["Typeahead_autocomplete"]["results"]
            results = [r["details"] for r in results]  # strip metadata
            
            log.info(f"Found {len(results)} results")
            return results
            
        except Exception as e:
            log.error(f"Error scraping location data: {e}")
            return []

    def parse_search_page(self, response: httpx.Response) -> List[Preview]:
        """Parse result previews from TripAdvisor search page"""
        log.info(f"Parsing search page: {response.url}")
        parsed = []
        selector = Selector(response.text)
        
        # Search results are contained in boxes which can be in two locations
        # Location #1: Modern layout
        for box in selector.css("span.listItem"):
            title_elements = box.css("div[data-automation=hotel-card-title] a ::text").getall()
            if len(title_elements) > 1:
                title = title_elements[1]
                url = box.css("div[data-automation=hotel-card-title] a::attr(href)").get()
                if title and url:
                    parsed.append({
                        "url": urljoin(str(response.url), url),
                        "name": title,
                    })
        
        if parsed:
            return parsed
        
        # Location #2: Legacy layout
        for box in selector.css("div.listing_title>a"):
            url = box.xpath("@href").get()
            name = box.xpath("text()").get("")
            if name:
                name = name.split(". ")[-1]  # Remove numbering
            if url and name:
                parsed.append({
                    "url": urljoin(str(response.url), url),
                    "name": name,
                })
        
        return parsed

    async def scrape_search(self, query: str, max_pages: Optional[int] = None) -> List[Preview]:
        """Scrape search results of a search query"""
        log.info(f"{query}: Scraping first search results page")
        
        try:
            location_data = (await self.scrape_location_data(query))[0]  # Take first result
        except IndexError:
            log.error(f"Could not find location data for query {query}")
            return []
        
        hotel_search_url = "https://www.tripadvisor.com" + location_data["HOTELS_URL"]
        log.info(f"Found hotel search url: {hotel_search_url}")
        
        try:
            first_page = await self.client.get(hotel_search_url)
            first_page.raise_for_status()
        except Exception as e:
            log.error(f"Error scraping first page: {e}")
            return []
        
        # Parse first page
        results = self.parse_search_page(first_page)
        if not results:
            log.error(f"Query {query} found no results")
            return []
        
        # Extract pagination metadata to scrape all pages concurrently
        page_size = len(results)
        selector = Selector(first_page.text)
        
        # Try to find total results
        total_results_text = selector.xpath("//span/text()").re(r"(\d*,*\d+) properties")
        if total_results_text:
            total_results = int(total_results_text[0].replace(",", ""))
            total_pages = int(math.ceil(total_results / page_size))
        else:
            # Fallback: just scrape a few pages
            total_pages = 5
            total_results = total_pages * page_size
        
        if max_pages and total_pages > max_pages:
            log.debug(f"{query}: Only scraping {max_pages} max pages from {total_pages} total")
            total_pages = max_pages
        
        log.info(f"{query}: Found {total_results} results, {page_size} per page. Scraping {total_pages} pages")
        
        # Get next page URL pattern
        next_page_url = selector.css('a[aria-label="Next page"]::attr(href)').get()
        if not next_page_url:
            return results  # Only one page available
        
        next_page_url = urljoin(hotel_search_url, next_page_url)
        
        # Generate URLs for remaining pages
        other_page_urls = [
            next_page_url.replace(f"oa{page_size}", f"oa{page_size * i}")
            for i in range(1, total_pages)
        ]
        
        # Scrape remaining pages concurrently
        tasks = [self.client.get(url) for url in other_page_urls]
        for task in asyncio.as_completed(tasks):
            try:
                response = await task
                response.raise_for_status()
                results.extend(self.parse_search_page(response))
            except Exception as e:
                log.error(f"Error scraping page: {e}")
                continue
        
        return results

    def parse_hotel_page(self, response: httpx.Response) -> Dict:
        """Parse hotel data from hotel pages"""
        selector = Selector(response.text)
        
        # Extract structured data (JSON-LD)
        basic_data = {}
        json_ld_scripts = selector.xpath("//script[contains(text(),'aggregateRating')]/text()").getall()
        for script in json_ld_scripts:
            try:
                basic_data = json.loads(script)
                break
            except json.JSONDecodeError:
                continue
        
        # Extract description
        description = selector.css("div.fIrGe._T::text").get()
        if not description:
            # Alternative selector
            description = selector.css("div.pIRBV._T::text").get()
        
        # Extract amenities/features
        amenities = []
        for feature in selector.xpath("//div[contains(@data-test-target, 'amenity')]/text()"):
            amenity = feature.get()
            if amenity:
                amenities.append(amenity)
        
        # Extract reviews
        reviews = []
        for review in selector.xpath("//div[@data-reviewid]"):
            title = review.xpath(".//div[@data-test-target='review-title']/a/span/span/text()").get()
            text = "".join(review.xpath(".//span[contains(@data-automation, 'reviewText')]/span/text()").extract())
            
            # Extract rating
            rate = review.xpath(".//div[@data-test-target='review-rating']/span/@class").get()
            if rate and "ui_bubble_rating" in rate:
                try:
                    rate_num = rate.split("ui_bubble_rating")[-1].split("_")[-1].replace("0", "")
                    rate = int(rate_num) if rate_num.isdigit() else None
                except:
                    rate = None
            else:
                rate = None
            
            # Extract trip date
            trip_data = review.xpath(".//span[span[contains(text(),'Date of stay')]]/text()").get()
            
            if title or text:  # Only add if we have some content
                reviews.append({
                    "title": title,
                    "text": text,
                    "rate": rate,
                    "tripDate": trip_data
                })
        
        return {
            "basic_data": basic_data,
            "description": description,
            "features": amenities,
            "reviews": reviews
        }

    async def scrape_hotel(self, url: str, max_review_pages: Optional[int] = None) -> Dict:
        """Scrape hotel data and reviews"""
        log.info(f"Scraping hotel: {url}")
        
        try:
            first_page = await self.client.get(url)
            first_page.raise_for_status()
        except Exception as e:
            log.error(f"Error scraping hotel page: {e}")
            return {}
        
        hotel_data = self.parse_hotel_page(first_page)
        
        # Get the number of total review pages
        review_page_size = 10
        total_reviews = 0
        
        if hotel_data.get("basic_data") and "aggregateRating" in hotel_data["basic_data"]:
            try:
                total_reviews = int(hotel_data["basic_data"]["aggregateRating"]["reviewCount"])
            except (ValueError, KeyError):
                total_reviews = len(hotel_data["reviews"]) * 10  # Estimate
        
        if total_reviews > 0:
            total_review_pages = math.ceil(total_reviews / review_page_size)
            
            # Limit review pages if specified
            if max_review_pages and max_review_pages < total_review_pages:
                total_review_pages = max_review_pages
            
            # Scrape additional review pages concurrently
            review_urls = [
                url.replace("-Reviews-", f"-Reviews-or{review_page_size * i}-")
                for i in range(1, total_review_pages)
            ]
            
            if review_urls:
                log.info(f"Scraping {len(review_urls)} additional review pages")
                tasks = [self.client.get(review_url) for review_url in review_urls]
                
                for task in asyncio.as_completed(tasks):
                    try:
                        response = await task
                        response.raise_for_status()
                        page_data = self.parse_hotel_page(response)
                        hotel_data["reviews"].extend(page_data["reviews"])
                    except Exception as e:
                        log.error(f"Error scraping review page: {e}")
                        continue
        
        log.info(f"Scraped hotel data with {len(hotel_data.get('reviews', []))} reviews")
        return hotel_data

    async def scrape_search_by_type(self, query: str, search_type: str = "hotels", max_pages: Optional[int] = None) -> List[Preview]:
        """Scrape search results for different types (hotels, attractions, restaurants)"""
        log.info(f"{query}: Scraping {search_type} search results")
        
        try:
            location_data = (await self.scrape_location_data(query))[0]  # Take first result
        except IndexError:
            log.error(f"Could not find location data for query {query}")
            return []
        
        # Select the appropriate URL based on search type
        search_url_map = {
            "hotels": location_data.get("HOTELS_URL"),
            "attractions": location_data.get("ATTRACTIONS_URL"), 
            "restaurants": location_data.get("RESTAURANTS_URL")
        }
        
        search_url = search_url_map.get(search_type)
        if not search_url:
            log.error(f"No {search_type} URL found for location")
            return []
            
        full_search_url = "https://www.tripadvisor.com" + search_url
        log.info(f"Found {search_type} search url: {full_search_url}")
        
        try:
            first_page = await self.client.get(full_search_url)
            first_page.raise_for_status()
        except Exception as e:
            log.error(f"Error scraping first page: {e}")
            return []
        
        # Parse first page using the same logic but with different selectors for each type
        if search_type == "hotels":
            results = self.parse_search_page(first_page)
        elif search_type == "attractions":
            results = self.parse_attractions_search_page(first_page)
        elif search_type == "restaurants":
            results = self.parse_restaurants_search_page(first_page)
        else:
            results = []
            
        if not results:
            log.error(f"Query {query} found no {search_type} results")
            return []
        
        # Extract pagination metadata
        page_size = len(results)
        selector = Selector(first_page.text)
        
        # Try to find total results - different text for each type
        result_patterns = {
            "hotels": r"(\d*,*\d+) properties",
            "attractions": r"(\d*,*\d+) results",
            "restaurants": r"(\d*,*\d+) restaurants"
        }
        
        pattern = result_patterns.get(search_type, r"(\d*,*\d+) results")
        total_results_text = selector.xpath("//span/text()").re(pattern)
        
        if total_results_text:
            total_results = int(total_results_text[0].replace(",", ""))
            total_pages = int(math.ceil(total_results / page_size))
        else:
            total_pages = 5
            total_results = total_pages * page_size
        
        if max_pages and total_pages > max_pages:
            log.debug(f"{query}: Only scraping {max_pages} max pages from {total_pages} total")
            total_pages = max_pages
        
        log.info(f"{query}: Found {total_results} {search_type}, {page_size} per page. Scraping {total_pages} pages")
        
        # Get pagination URLs
        next_page_url = selector.css('a[aria-label="Next page"]::attr(href)').get()
        if not next_page_url:
            return results
        
        next_page_url = urljoin(full_search_url, next_page_url)
        
        # Generate URLs for remaining pages
        other_page_urls = [
            next_page_url.replace(f"oa{page_size}", f"oa{page_size * i}")
            for i in range(1, total_pages)
        ]
        
        # Scrape remaining pages concurrently
        tasks = [self.client.get(url) for url in other_page_urls]
        for task in asyncio.as_completed(tasks):
            try:
                response = await task
                response.raise_for_status()
                if search_type == "hotels":
                    results.extend(self.parse_search_page(response))
                elif search_type == "attractions":
                    results.extend(self.parse_attractions_search_page(response))
                elif search_type == "restaurants":
                    results.extend(self.parse_restaurants_search_page(response))
            except Exception as e:
                log.error(f"Error scraping page: {e}")
                continue
        
        return results

    def parse_attractions_search_page(self, response: httpx.Response) -> List[Preview]:
        """Parse attraction previews from TripAdvisor search page"""
        log.info(f"Parsing attractions search page: {response.url}")
        parsed = []
        selector = Selector(response.text)
        
        # Attractions have different selectors
        for box in selector.css("div.attraction_element, div.listing"):
            # Try multiple selectors for attraction name and URL
            title = (
                box.css("div.listing_title a::text").get() or
                box.css("h3 a::text").get() or
                box.css(".attractions-attraction-overview-main-Attraction__heading a::text").get()
            )
            
            url = (
                box.css("div.listing_title a::attr(href)").get() or
                box.css("h3 a::attr(href)").get() or
                box.css(".attractions-attraction-overview-main-Attraction__heading a::attr(href)").get()
            )
            
            if title and url:
                # Clean up title (remove numbering)
                title = title.split(". ")[-1] if ". " in title else title
                parsed.append({
                    "url": urljoin(str(response.url), url),
                    "name": title.strip(),
                })
        
        return parsed

    def parse_restaurants_search_page(self, response: httpx.Response) -> List[Preview]:
        """Parse restaurant previews from TripAdvisor search page"""
        log.info(f"Parsing restaurants search page: {response.url}")
        parsed = []
        selector = Selector(response.text)
        
        # Restaurants have their own selectors
        for box in selector.css("div.restaurant, div.listing"):
            # Try multiple selectors for restaurant name and URL
            title = (
                box.css("a.restaurants-list-ListCell__restaurantName--2aSC2::text").get() or
                box.css("div.listing_title a::text").get() or
                box.css("h3 a::text").get() or
                box.css(".restaurants-list-ListCell__restaurantName a::text").get()
            )
            
            url = (
                box.css("a.restaurants-list-ListCell__restaurantName--2aSC2::attr(href)").get() or
                box.css("div.listing_title a::attr(href)").get() or
                box.css("h3 a::attr(href)").get() or
                box.css(".restaurants-list-ListCell__restaurantName a::attr(href)").get()
            )
            
            if title and url:
                # Clean up title
                title = title.split(". ")[-1] if ". " in title else title
                parsed.append({
                    "url": urljoin(str(response.url), url),
                    "name": title.strip(),
                })
        
        return parsed

    async def scrape_attraction(self, url: str, max_review_pages: Optional[int] = None) -> Dict:
        """Scrape attraction data and reviews"""
        log.info(f"Scraping attraction: {url}")
        
        try:
            first_page = await self.client.get(url)
            first_page.raise_for_status()
        except Exception as e:
            log.error(f"Error scraping attraction page: {e}")
            return {}
        
        attraction_data = self.parse_attraction_page(first_page)
        
        # Handle review pagination for attractions
        review_page_size = 10
        total_reviews = 0
        
        if attraction_data.get("basic_data") and "aggregateRating" in attraction_data["basic_data"]:
            try:
                total_reviews = int(attraction_data["basic_data"]["aggregateRating"]["reviewCount"])
            except (ValueError, KeyError):
                total_reviews = len(attraction_data["reviews"]) * 10
        
        if total_reviews > 0 and max_review_pages:
            total_review_pages = min(max_review_pages, math.ceil(total_reviews / review_page_size))
            
            review_urls = [
                url.replace("-Reviews-", f"-Reviews-or{review_page_size * i}-")
                for i in range(1, total_review_pages)
            ]
            
            if review_urls:
                log.info(f"Scraping {len(review_urls)} additional review pages")
                tasks = [self.client.get(review_url) for review_url in review_urls]
                
                for task in asyncio.as_completed(tasks):
                    try:
                        response = await task
                        response.raise_for_status()
                        page_data = self.parse_attraction_page(response)
                        attraction_data["reviews"].extend(page_data["reviews"])
                    except Exception as e:
                        log.error(f"Error scraping review page: {e}")
                        continue
        
        log.info(f"Scraped attraction data with {len(attraction_data.get('reviews', []))} reviews")
        return attraction_data

    def parse_attraction_page(self, response: httpx.Response) -> Dict:
        """Parse attraction data from attraction pages"""
        selector = Selector(response.text)
        
        # Extract JSON-LD structured data
        basic_data = {}
        json_ld_scripts = selector.xpath("//script[contains(text(),'aggregateRating') or contains(text(),'TouristAttraction')]/text()").getall()
        for script in json_ld_scripts:
            try:
                basic_data = json.loads(script)
                break
            except json.JSONDecodeError:
                continue
        
        # Extract description
        description = (
            selector.css("div.attractions-attraction-detail-about-card-AttractionDetailAboutCard__content--2tOh0::text").get() or
            selector.css("div.fIrGe._T::text").get() or
            selector.css("div.pIRBV._T::text").get()
        )
        
        # Extract features/highlights
        features = []
        for feature in selector.css("div.attractions-attraction-detail-about-card-AttractionDetailAboutCard__highlights li::text"):
            features.append(feature.get())
        
        # Extract reviews
        reviews = []
        for review in selector.xpath("//div[@data-reviewid]"):
            title = review.xpath(".//div[@data-test-target='review-title']/a/span/span/text()").get()
            text = "".join(review.xpath(".//span[contains(@data-automation, 'reviewText')]/span/text()").extract())
            
            # Extract rating
            rate = review.xpath(".//div[@data-test-target='review-rating']/span/@class").get()
            if rate and "ui_bubble_rating" in rate:
                try:
                    rate_num = rate.split("ui_bubble_rating")[-1].split("_")[-1].replace("0", "")
                    rate = int(rate_num) if rate_num.isdigit() else None
                except:
                    rate = None
            else:
                rate = None
            
            trip_data = review.xpath(".//span[span[contains(text(),'Date of visit')]]/text()").get()
            
            if title or text:
                reviews.append({
                    "title": title,
                    "text": text,
                    "rate": rate,
                    "visitDate": trip_data
                })
        
        return {
            "basic_data": basic_data,
            "description": description,
            "features": features,
            "reviews": reviews
        }

    async def scrape_restaurant(self, url: str, max_review_pages: Optional[int] = None) -> Dict:
        """Scrape restaurant data and reviews"""
        log.info(f"Scraping restaurant: {url}")
        
        try:
            first_page = await self.client.get(url)
            first_page.raise_for_status()
        except Exception as e:
            log.error(f"Error scraping restaurant page: {e}")
            return {}
        
        restaurant_data = self.parse_restaurant_page(first_page)
        
        # Handle review pagination for restaurants
        review_page_size = 10
        total_reviews = 0
        
        if restaurant_data.get("basic_data") and "aggregateRating" in restaurant_data["basic_data"]:
            try:
                total_reviews = int(restaurant_data["basic_data"]["aggregateRating"]["reviewCount"])
            except (ValueError, KeyError):
                total_reviews = len(restaurant_data["reviews"]) * 10
        
        if total_reviews > 0 and max_review_pages:
            total_review_pages = min(max_review_pages, math.ceil(total_reviews / review_page_size))
            
            review_urls = [
                url.replace("-Reviews-", f"-Reviews-or{review_page_size * i}-")
                for i in range(1, total_review_pages)
            ]
            
            if review_urls:
                log.info(f"Scraping {len(review_urls)} additional review pages")
                tasks = [self.client.get(review_url) for review_url in review_urls]
                
                for task in asyncio.as_completed(tasks):
                    try:
                        response = await task
                        response.raise_for_status()
                        page_data = self.parse_restaurant_page(response)
                        restaurant_data["reviews"].extend(page_data["reviews"])
                    except Exception as e:
                        log.error(f"Error scraping review page: {e}")
                        continue
        
        log.info(f"Scraped restaurant data with {len(restaurant_data.get('reviews', []))} reviews")
        return restaurant_data

    def parse_restaurant_page(self, response: httpx.Response) -> Dict:
        """Parse restaurant data from restaurant pages"""
        selector = Selector(response.text)
        
        # Extract JSON-LD structured data
        basic_data = {}
        json_ld_scripts = selector.xpath("//script[contains(text(),'aggregateRating') or contains(text(),'Restaurant')]/text()").getall()
        for script in json_ld_scripts:
            try:
                basic_data = json.loads(script)
                break
            except json.JSONDecodeError:
                continue
        
        # Extract description
        description = (
            selector.css("div.restaurants-detail-overview-cards-DetailOverviewCards__tagText--1vh6O::text").get() or
            selector.css("div.fIrGe._T::text").get() or
            selector.css("div.pIRBV._T::text").get()
        )
        
        # Extract cuisine types and features
        features = []
        for feature in selector.css("div.restaurants-detail-overview-cards-DetailOverviewCards__tagText--1vh6O span::text"):
            features.append(feature.get())
        
        # Extract price range
        price_range = selector.css("div.restaurants-detail-overview-cards-DetailOverviewCards__priceRange::text").get()
        if price_range:
            features.append(f"Price Range: {price_range}")
        
        # Extract reviews
        reviews = []
        for review in selector.xpath("//div[@data-reviewid]"):
            title = review.xpath(".//div[@data-test-target='review-title']/a/span/span/text()").get()
            text = "".join(review.xpath(".//span[contains(@data-automation, 'reviewText')]/span/text()").extract())
            
            # Extract rating
            rate = review.xpath(".//div[@data-test-target='review-rating']/span/@class").get()
            if rate and "ui_bubble_rating" in rate:
                try:
                    rate_num = rate.split("ui_bubble_rating")[-1].split("_")[-1].replace("0", "")
                    rate = int(rate_num) if rate_num.isdigit() else None
                except:
                    rate = None
            else:
                rate = None
            
            visit_data = review.xpath(".//span[span[contains(text(),'Date of visit')]]/text()").get()
            
            if title or text:
                reviews.append({
                    "title": title,
                    "text": text,
                    "rate": rate,
                    "visitDate": visit_data
                })
        
        return {
            "basic_data": basic_data,
            "description": description,
            "features": features,
            "reviews": reviews
        }

    async def scrape_hotels_from_search(self, query: str, max_hotels: Optional[int] = None, 
                                      max_review_pages_per_hotel: Optional[int] = 3) -> List[Dict]:
        """Complete workflow: search for hotels and scrape their data"""
        return await self.scrape_by_type(query, "hotels", max_hotels, max_review_pages_per_hotel)

    async def scrape_attractions_from_search(self, query: str, max_attractions: Optional[int] = None, 
                                           max_review_pages_per_attraction: Optional[int] = 3) -> List[Dict]:
        """Complete workflow: search for attractions and scrape their data"""
        return await self.scrape_by_type(query, "attractions", max_attractions, max_review_pages_per_attraction)

    async def scrape_restaurants_from_search(self, query: str, max_restaurants: Optional[int] = None, 
                                           max_review_pages_per_restaurant: Optional[int] = 3) -> List[Dict]:
        """Complete workflow: search for restaurants and scrape their data"""
        return await self.scrape_by_type(query, "restaurants", max_restaurants, max_review_pages_per_restaurant)

    async def scrape_by_type(self, query: str, content_type: str, max_items: Optional[int] = None, 
                           max_review_pages_per_item: Optional[int] = 3) -> List[Dict]:
        """Generic workflow for scraping different content types"""
        log.info(f"Starting complete scrape for {content_type} in {query}")
        
        # Get search results for the specified type
        search_results = await self.scrape_search_by_type(query, content_type, max_pages=5)
        
        if not search_results:
            log.error(f"No {content_type} search results found for {query}")
            return []
        
        # Limit number of items to scrape
        if max_items:
            search_results = search_results[:max_items]
        
        log.info(f"Found {len(search_results)} {content_type} to scrape")
        
        # Scrape each item's detailed data
        items_data_list = []
        for i, item_preview in enumerate(search_results):
            log.info(f"Scraping {content_type[:-1]} {i+1}/{len(search_results)}: {item_preview['name']}")
            
            # Call appropriate scraper based on type
            if content_type == "hotels":
                item_data = await self.scrape_hotel(item_preview["url"], max_review_pages=max_review_pages_per_item)
            elif content_type == "attractions":
                item_data = await self.scrape_attraction(item_preview["url"], max_review_pages=max_review_pages_per_item)
            elif content_type == "restaurants":
                item_data = await self.scrape_restaurant(item_preview["url"], max_review_pages=max_review_pages_per_item)
            else:
                continue
            
            if item_data:
                item_data["preview"] = item_preview
                item_data["type"] = content_type[:-1]  # Remove 's' from end
                items_data_list.append(item_data)
            
            # Add delay to be respectful
            await asyncio.sleep(1)
        
        return items_data_list

    async def close(self):
        """Close the HTTP client"""
        await self.client.aclose()

# Example usage and testing functions
async def test_location_search():
    """Test location search functionality"""
    scraper = TripAdvisorScraper()
    try:
        results = await scraper.scrape_location_data("Malta")
        print("Location search results:")
        print(json.dumps(results, indent=2))
    finally:
        await scraper.close()

async def test_hotel_search():
    """Test hotel search functionality"""
    scraper = TripAdvisorScraper()
    try:
        results = await scraper.scrape_search_by_type("Malta", "hotels", max_pages=2)
        print(f"Found {len(results)} hotels:")
        for hotel in results[:5]:
            print(f"- {hotel['name']}: {hotel['url']}")
    finally:
        await scraper.close()

async def test_attractions_search():
    """Test attractions search functionality"""
    scraper = TripAdvisorScraper()
    try:
        results = await scraper.scrape_search_by_type("Malta", "attractions", max_pages=2)
        print(f"Found {len(results)} attractions:")
        for attraction in results[:5]:
            print(f"- {attraction['name']}: {attraction['url']}")
    finally:
        await scraper.close()

async def test_restaurants_search():
    """Test restaurants search functionality"""
    scraper = TripAdvisorScraper()
    try:
        results = await scraper.scrape_search_by_type("Malta", "restaurants", max_pages=2)
        print(f"Found {len(results)} restaurants:")
        for restaurant in results[:5]:
            print(f"- {restaurant['name']}: {restaurant['url']}")
    finally:
        await scraper.close()

async def test_hotel_scraping():
    """Test individual hotel scraping"""
    scraper = TripAdvisorScraper()
    try:
        # Example hotel URL - replace with actual URL
        hotel_url = "https://www.tripadvisor.com/Hotel_Review-g190327-d264936-Reviews-1926_Hotel_Spa-Sliema_Island_of_Malta.html"
        hotel_data = await scraper.scrape_hotel(hotel_url, max_review_pages=2)
        
        print("Hotel data:")
        print(f"Name: {hotel_data.get('basic_data', {}).get('name', 'N/A')}")
        print(f"Rating: {hotel_data.get('basic_data', {}).get('aggregateRating', {}).get('ratingValue', 'N/A')}")
        print(f"Review count: {len(hotel_data.get('reviews', []))}")
        print(f"Features count: {len(hotel_data.get('features', []))}")
        
    finally:
        await scraper.close()

async def main():
    """Main function for complete workflow"""
    scraper = TripAdvisorScraper()
    try:
        # Example: Search for different types of content in Malta
        print("🏨 Scraping Hotels...")
        hotels_data = await scraper.scrape_hotels_from_search(
            query="Malta", 
            max_hotels=2, 
            max_review_pages_per_hotel=1
        )
        
        print("🎯 Scraping Attractions...")
        attractions_data = await scraper.scrape_attractions_from_search(
            query="Malta", 
            max_attractions=2, 
            max_review_pages_per_attraction=1
        )
        
        print("🍽️ Scraping Restaurants...")
        restaurants_data = await scraper.scrape_restaurants_from_search(
            query="Malta", 
            max_restaurants=2, 
            max_review_pages_per_restaurant=1
        )
        
        # Combine all data
        all_data = {
            "hotels": hotels_data,
            "attractions": attractions_data,
            "restaurants": restaurants_data
        }
        
        print(f"\n📊 SCRAPING SUMMARY:")
        print(f"Hotels: {len(hotels_data)}")
        print(f"Attractions: {len(attractions_data)}")
        print(f"Restaurants: {len(restaurants_data)}")
        
        for content_type, items in all_data.items():
            for item in items:
                basic_data = item.get('basic_data', {})
                print(f"\n{content_type.upper()}: {basic_data.get('name', 'Unknown')}")
                print(f"  Rating: {basic_data.get('aggregateRating', {}).get('ratingValue', 'N/A')}")
                print(f"  Reviews scraped: {len(item.get('reviews', []))}")
                print(f"  Features: {len(item.get('features', []))}")
        
        # Save results to file
        with open("tripadvisor_all_data.json", "w", encoding="utf-8") as f:
            json.dump(all_data, f, indent=2, ensure_ascii=False)
        print("\nResults saved to tripadvisor_all_data.json")
        
    finally:
        await scraper.close()

if __name__ == "__main__":
    # Run different test functions
    # asyncio.run(test_location_search())
    # asyncio.run(test_hotel_search())
    # asyncio.run(test_attractions_search())
    # asyncio.run(test_restaurants_search())
    # asyncio.run(test_hotel_scraping())
    asyncio.run(main())
