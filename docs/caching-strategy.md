# Caching Strategy

The RouteWise API implements a sophisticated multi-tier caching system designed for high performance, scalability, and fault tolerance. This document explains the caching architecture, backends, and best practices.

## Overview

Our caching system provides:
- **Multiple Backend Support**: Memory, Redis, and Hybrid configurations
- **Intelligent TTL Management**: Context-aware expiration policies
- **Fault Tolerance**: Graceful degradation when cache layers fail
- **Debug Support**: Comprehensive logging and statistics
- **Performance Optimization**: L1/L2 cache promotion and memory pressure management

## Architecture

### Cache Layers

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │────│  Cache Frontend  │────│  Configuration  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
    ┌───────▼─────┐    ┌────────▼────────┐    ┌────▼────────┐
    │   Memory    │    │     Redis       │    │   Hybrid    │
    │  Backend    │    │    Backend      │    │  Backend    │
    └─────────────┘    └─────────────────┘    └─────────────┘
```

### Backend Selection

The cache system uses a configurable backend approach:

```elixir
# Development - Fast, local
config :phoenix_backend, RouteWiseApi.Caching,
  backend: RouteWiseApi.Caching.Backend.Memory

# Production - Distributed, persistent
config :phoenix_backend, RouteWiseApi.Caching,
  backend: RouteWiseApi.Caching.Backend.Redis

# High-performance - Best of both worlds
config :phoenix_backend, RouteWiseApi.Caching,
  backend: RouteWiseApi.Caching.Backend.Hybrid
```

## Cache Backends

### Memory Backend

**Purpose**: Fast, local caching for development and single-node deployments.

**Features**:
- In-memory storage using the existing `RouteWiseApi.Cache` GenServer
- Process timer-based expiration
- Debug logging for cache operations
- Fault tolerance with error recovery
- Health checking with functional tests

**Use Cases**:
- Development environment
- Single-node applications
- Hot data that needs sub-millisecond access

**Performance**: ~0.1ms average response time

```elixir
# Example usage
RouteWiseApi.Caching.Backend.Memory.put("user:123", user_data, 300_000)  # 5 min TTL
{:ok, user_data} = RouteWiseApi.Caching.Backend.Memory.get("user:123")
```

### Redis Backend

**Purpose**: Distributed, persistent caching for multi-node production deployments.

**Features**:
- Redis-based distributed caching
- Persistence across application restarts
- Cluster support for high availability
- Pattern-based invalidation
- Production-grade performance

**Use Cases**:
- Production deployments
- Multi-node applications
- Data that needs persistence
- Cross-service caching

**Performance**: ~1-3ms average response time (network dependent)

### Hybrid Backend

**Purpose**: Intelligent two-tier caching combining L1 (memory) and L2 (Redis).

**Architecture**:
```
L1 Cache (Memory)     L2 Cache (Redis)
┌─────────────────┐   ┌─────────────────┐
│  Hot Data       │   │  All Data       │
│  <1000 keys     │   │  Persistent     │
│  Fast Access    │   │  Distributed    │
│  <1ms latency   │   │  1-3ms latency  │
└─────────────────┘   └─────────────────┘
```

**Intelligence Features**:
- **Automatic Promotion**: L2 → L1 after 3 hits
- **Memory Pressure Management**: Smart L1 eviction
- **Distributed Invalidation**: PubSub-based cache coherence
- **Graceful Degradation**: Continues with single layer if one fails

**Performance**: 
- L1 hit: ~0.1ms
- L2 hit with promotion: ~1-3ms
- Cache miss: Variable (depends on data source)

## TTL Configuration

### TTL Levels

```elixir
# TTL configuration examples
Config.ttl(:short)   # 5 minutes  - Frequently changing data
Config.ttl(:medium)  # 15 minutes - Moderate update frequency
Config.ttl(:long)    # 1 hour     - Relatively static data
Config.ttl(:extended) # 24 hours  - Very static data
```

### TTL Strategies by Data Type

| Data Type | TTL | Backend | Reasoning |
|-----------|-----|---------|-----------|
| **User Sessions** | Short (5m) | Hybrid | Security & state changes |
| **Google Places** | Long (1h) | Hybrid | Static POI data, expensive API calls |
| **Route Calculations** | Medium (15m) | Redis | Traffic changes moderately |
| **Application Stats** | Medium (15m) | Memory | Dashboard performance |
| **API Rate Limits** | Short (5m) | Redis | Need distributed tracking |

### Context-Aware Caching

Different contexts use appropriate TTL and backends:

```elixir
# Places - Long TTL, hybrid backend (expensive API calls)
RouteWiseApi.Caching.Places.put_cache(place_id, place_data, Config.ttl(:long))

# Statistics - Medium TTL, memory backend (frequently accessed)
RouteWiseApi.Caching.Statistics.put_cache(stats, Config.ttl(:medium))

# Trips - Medium TTL, hybrid backend (user-specific, moderately static)
RouteWiseApi.Caching.Trips.put_cache(trip_id, trip_data, Config.ttl(:medium))
```

## Cache Keys

### Naming Convention

```
<domain>:<identifier>[:<sub_identifier>]
```

Examples:
- `user:123` - User data
- `place:ChIJd8BlQ2BZwokRAFQEcDL4vOE` - Google Place details
- `route:37.7749,-122.4194:37.7849,-122.4094` - Route calculation
- `stats:application` - Application statistics
- `trips:user:123` - User's trips

### Key Benefits

- **Namespace Separation**: Prevents key collisions
- **Pattern Invalidation**: Easy bulk invalidation (`user:*`)
- **Debugging**: Clear identification of cached data
- **TTL Management**: Different TTLs per namespace

## Performance Optimization

### Memory Backend Optimization

```elixir
# Efficient key management
- Process timers for immediate expiration
- Periodic cleanup (60-second intervals)
- Memory pressure monitoring
- Graceful cleanup on expired access
```

### Hybrid Backend Optimization

```elixir
# Intelligent promotion algorithm
hit_threshold = 3  # Promote after 3 L2 hits
memory_limit = 1000  # Max keys in L1

# Promotion logic
if l2_hits >= hit_threshold && l1_keys < memory_limit do
  promote_to_l1(key, data)
end
```

### Cache Warming

Pre-populate frequently accessed data:

```elixir
# Application startup cache warming
def warm_cache do
  # Pre-load popular places
  popular_places = get_popular_places()
  Enum.each(popular_places, &cache_place_details/1)
  
  # Pre-calculate common routes
  common_routes = get_common_routes()
  Enum.each(common_routes, &cache_route_calculation/1)
end
```

## Monitoring and Debugging

### Health Checks

```elixir
# Backend health verification
RouteWiseApi.Caching.Backend.Memory.health_check()
# => :ok | {:error, reason}

# Comprehensive hybrid health check
RouteWiseApi.Caching.Backend.Hybrid.health_check()
# => :ok (both layers healthy)
# => :ok (one layer degraded but functional)
# => {:error, :all_backends_unhealthy}
```

### Statistics and Monitoring

```elixir
# Memory backend stats
%{
  total_keys: 150,
  expired_keys: 5,
  active_timers: 145,
  backend: "memory",
  health_status: :healthy
}

# Hybrid backend stats
%{
  backend: "hybrid",
  l1_stats: %{total_keys: 50, health_status: :healthy},
  l2_stats: %{total_keys: 500, health_status: :healthy},
  hit_tracking: %{"user:123" => 5, "place:abc" => 3},
  health_status: :healthy
}
```

### Debug Logging

Enable debug logging to track cache behavior:

```elixir
config :phoenix_backend, RouteWiseApi.Caching,
  enable_logging: true,
  debug_mode: true

# Log output examples:
# [debug] Cache HIT: user:123
# [debug] Cache MISS: user:456
# [debug] Promoted place:abc to L1 cache after 3 hits
# [debug] Cache PUT: route:coordinates (TTL: 900000ms)
```

## Best Practices

### 1. Choose Appropriate TTLs

```elixir
# ✅ Good: Match TTL to data characteristics
user_profile_ttl = Config.ttl(:medium)    # Updates occasionally
api_rate_limit_ttl = Config.ttl(:short)   # Updates frequently
poi_data_ttl = Config.ttl(:long)          # Updates rarely

# ❌ Bad: One-size-fits-all TTL
everything_ttl = Config.ttl(:medium)
```

### 2. Handle Cache Failures Gracefully

```elixir
# ✅ Good: Graceful degradation
def get_user_data(user_id) do
  case Cache.get("user:#{user_id}") do
    {:ok, data} -> 
      {:ok, data}
    :error -> 
      # Fallback to database
      fetch_and_cache_user(user_id)
  end
end

# ❌ Bad: Cache dependency
def get_user_data(user_id) do
  Cache.get("user:#{user_id}")  # Fails if cache unavailable
end
```

### 3. Use Structured Cache Keys

```elixir
# ✅ Good: Structured, predictable keys
"user:#{user_id}:profile"
"place:#{place_id}:details"
"route:#{origin}:#{destination}:#{mode}"

# ❌ Bad: Unstructured keys
"user_profile_123"
"some_place_data"
"route_calculation_result"
```

### 4. Implement Cache Invalidation

```elixir
# ✅ Good: Proactive invalidation
def update_user_profile(user_id, new_data) do
  case Accounts.update_user(user_id, new_data) do
    {:ok, user} ->
      # Invalidate related cache entries
      Cache.delete("user:#{user_id}:profile")
      Cache.invalidate_pattern("user:#{user_id}:*")
      {:ok, user}
    error -> error
  end
end
```

## Troubleshooting

### Common Issues

1. **Cache Misses**: Check TTL settings and key naming
2. **Memory Growth**: Monitor cleanup intervals and expired key handling
3. **Redis Connection**: Verify Redis server availability and network connectivity
4. **Performance**: Use hybrid backend for optimal L1/L2 balance

### Debug Commands

```elixir
# Check cache health
RouteWiseApi.Caching.Backend.Memory.health_check()

# View cache statistics
RouteWiseApi.Caching.Backend.Memory.stats()

# Test cache functionality
Cache.put("test", "value", 5000)
Cache.get("test")  # Should return {:ok, "value"}
```

## Configuration Examples

### Development Configuration

```elixir
config :phoenix_backend, RouteWiseApi.Caching,
  backend: RouteWiseApi.Caching.Backend.Memory,
  enable_logging: true,
  debug_mode: true,
  ttl_multiplier: 0.1  # Shorter TTLs for development
```

### Production Configuration

```elixir
config :phoenix_backend, RouteWiseApi.Caching,
  backend: RouteWiseApi.Caching.Backend.Hybrid,
  enable_logging: false,
  debug_mode: false,
  ttl_multiplier: 1.0,
  invalidation: [
    distributed: true,
    pubsub_server: RouteWiseApi.PubSub
  ]
```

### Testing Configuration

```elixir
config :phoenix_backend, RouteWiseApi.Caching,
  backend: RouteWiseApi.Caching.Backend.Memory,
  enable_logging: false,
  debug_mode: false,
  ttl_multiplier: 0.01  # Very short TTLs for fast tests
```

This caching strategy provides the foundation for a high-performance, scalable API while maintaining simplicity in development and robustness in production.