# Real-Time Scraping API Documentation

Complete guide for implementing real-time place data collection with automatic TripAdvisor scraping.

## 🚀 How It Works

When a user searches for places and gets no results:

1. **Instant Response**: API immediately responds with empty results + scraping status
2. **Background Scraping**: Python scraper runs in background (30-60 seconds)  
3. **Real-Time Updates**: User gets live updates via WebSocket or polling
4. **Database Import**: New places automatically imported to database
5. **Cached Results**: Future searches for same location return cached data

## 📡 API Endpoints

### 1. Live Search with Auto-Scraping

**Endpoint**: `GET /api/places/live-search`

**Parameters**:
- `query` (required) - City name (e.g., "Austin, TX", "Miami, FL")
- `lat`, `lng` (optional) - Coordinates for nearby search
- `radius` (optional) - Search radius in meters (default: 10000)

**Response - Has Data**:
```json
{
  "places": [
    {
      "id": "123",
      "name": "Restaurant Name",
      "latitude": 30.2672,
      "longitude": -97.7431,
      "address": "123 Main St",
      "rating": 4.5,
      "place_types": ["restaurant"],
      "data_source": "google_places"
    }
  ],
  "scraping_status": "not_needed",
  "total": 25
}
```

**Response - No Data (Triggers Scraping)**:
```json
{
  "places": [],
  "scraping_status": "started",
  "message": "Gathering place data for Austin, TX... This may take 30-60 seconds.",
  "estimated_completion": "2024-01-15T10:30:45Z",
  "subscribe_to": "user:abc123"
}
```

### 2. Check Scraping Status

**Endpoint**: `GET /api/places/scrape-status/:location`

**Response**:
```json
{
  "status": "running",  // or "completed", "failed"
  "message": "Scraping in progress...",
  "places_found": null,
  "started_at": "2024-01-15T10:30:00Z"
}
```

### 3. Polling for Updates

**Endpoint**: `GET /api/places/check-updates`

**Parameters**:
- `location` - Location being scraped
- `since` - Unix timestamp of last check

**Response**:
```json
{
  "new_places": [...],
  "count": 15,
  "last_check": 1642248645
}
```

## 🔌 WebSocket Real-Time Updates

### Connect to WebSocket

```javascript
// Connect to user-specific scraping updates
const socket = new Phoenix.Socket("/socket", {
  params: {token: userToken} // Optional for authenticated users
})

const channel = socket.channel("scraping:user_123")
```

### Listen for Updates

```javascript
// Scraping started
channel.on("scraping_update", (payload) => {
  if (payload.type === "scraping_started") {
    showLoadingState(payload.data.location, payload.data.estimated_time)
  }
})

// Scraping completed
channel.on("scraping_update", (payload) => {
  if (payload.type === "scraping_completed") {
    showResults(payload.data.location, payload.data.places_found)
    refreshPlacesList() // Reload the search results
  }
})

// Scraping failed
channel.on("scraping_update", (payload) => {
  if (payload.type === "scraping_failed") {
    showError("Unable to gather place data at this time")
  }
})
```

## 🔧 Frontend Implementation Examples

### React Hook for Real-Time Search

```javascript
import { useState, useEffect } from 'react'
import { Socket } from 'phoenix'

export const useRealTimeSearch = () => {
  const [places, setPlaces] = useState([])
  const [isLoading, setIsLoading] = useState(false)
  const [scrapingStatus, setScrapingStatus] = useState(null)
  const [socket, setSocket] = useState(null)

  useEffect(() => {
    // Initialize WebSocket
    const socket = new Socket("/socket")
    socket.connect()
    setSocket(socket)

    return () => socket.disconnect()
  }, [])

  const searchPlaces = async (query) => {
    setIsLoading(true)
    
    try {
      const response = await fetch(`/api/places/live-search?query=${encodeURIComponent(query)}`)
      const data = await response.json()
      
      if (data.places.length > 0) {
        // Found existing data
        setPlaces(data.places)
        setScrapingStatus('not_needed')
      } else if (data.scraping_status === 'started') {
        // Scraping started - listen for updates
        setScrapingStatus('scraping')
        listenForUpdates(data.subscribe_to)
      }
    } catch (error) {
      console.error('Search failed:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const listenForUpdates = (channelName) => {
    const channel = socket.channel(channelName)
    
    channel.on("scraping_update", (payload) => {
      if (payload.type === "scraping_completed") {
        setScrapingStatus('completed')
        // Refresh search results
        refreshResults()
      }
    })
    
    channel.join()
  }

  const refreshResults = async () => {
    // Re-run search to get new results
  }

  return {
    places,
    isLoading,
    scrapingStatus,
    searchPlaces
  }
}
```

### Vue.js Implementation

```javascript
// store/places.js
export const usePlacesStore = () => {
  const places = ref([])
  const isLoading = ref(false)
  const scrapingStatus = ref(null)
  
  const searchPlaces = async (query) => {
    isLoading.value = true
    
    const response = await $fetch('/api/places/live-search', {
      query: { query }
    })
    
    if (response.scraping_status === 'started') {
      // Connect to WebSocket for updates
      connectToScrapingUpdates(response.subscribe_to)
    } else {
      places.value = response.places
    }
    
    isLoading.value = false
  }
  
  return {
    places: readonly(places),
    isLoading: readonly(isLoading),
    scrapingStatus: readonly(scrapingStatus),
    searchPlaces
  }
}
```

### Vanilla JavaScript (No Framework)

```javascript
class RealTimeSearch {
  constructor() {
    this.places = []
    this.isLoading = false
    this.socket = new Phoenix.Socket("/socket")
    this.socket.connect()
  }

  async searchPlaces(query) {
    this.isLoading = true
    this.updateUI()

    const response = await fetch(`/api/places/live-search?query=${query}`)
    const data = await response.json()

    if (data.places.length > 0) {
      this.places = data.places
      this.renderResults()
    } else if (data.scraping_status === 'started') {
      this.showScrapingMessage(data.message)
      this.listenForUpdates(data.subscribe_to)
    }

    this.isLoading = false
  }

  listenForUpdates(channelName) {
    const channel = this.socket.channel(channelName)
    
    channel.on("scraping_update", (payload) => {
      if (payload.type === "scraping_completed") {
        this.showCompletionMessage(payload.data.places_found)
        setTimeout(() => this.refreshResults(), 1000)
      }
    })
    
    channel.join()
  }

  showScrapingMessage(message) {
    document.getElementById('results').innerHTML = `
      <div class="scraping-message">
        <div class="spinner"></div>
        <p>${message}</p>
      </div>
    `
  }

  renderResults() {
    const html = this.places.map(place => `
      <div class="place-card">
        <h3>${place.name}</h3>
        <p>${place.address}</p>
        <p>Rating: ${place.rating} ⭐</p>
      </div>
    `).join('')
    
    document.getElementById('results').innerHTML = html
  }
}
```

## ⚡ Performance Characteristics

**Scraping Speed**:
- **Quick Mode**: 30-45 seconds (3-5 search queries)
- **Full Mode**: 2-3 minutes (10+ search queries)
- **Rate Limited**: 2.5s delay between requests (required)

**Caching Strategy**:
- **24-hour cache**: Avoids re-scraping same locations
- **Threshold**: Only scrapes if <5 places found in database
- **Background**: Never blocks user requests

**Resource Usage**:
- **Memory**: ~50MB per scraping job
- **CPU**: Minimal (mostly network I/O)
- **Database**: Atomic transactions for data safety

## 🔐 Security & Rate Limiting

**Anti-Bot Protection**:
- ✅ Proper GraphQL headers with random X-Requested-By strings
- ✅ HTTP/2 connections for authenticity  
- ✅ Rate limiting (2.5s between requests)
- ✅ User-Agent rotation

**API Rate Limiting**:
- Max 1 scraping job per location per 24 hours
- Max 3 concurrent scraping jobs per user
- Graceful degradation when limits exceeded

## 🚀 Quick Integration

1. **Add the API call**:
```javascript
const searchPlaces = async (query) => {
  const response = await fetch(`/api/places/live-search?query=${query}`)
  return response.json()
}
```

2. **Handle scraping status**:
```javascript
if (data.scraping_status === 'started') {
  showLoadingMessage(data.message)
  // Set up polling or WebSocket
}
```

3. **Poll for updates** (alternative to WebSocket):
```javascript
const pollForUpdates = async (location) => {
  const response = await fetch(`/api/places/check-updates?location=${location}&since=${lastCheck}`)
  const data = await response.json()
  
  if (data.new_places.length > 0) {
    updatePlacesList(data.new_places)
  }
}
```

Your users get **instant feedback** with **real-time data collection** happening in the background! 🎯