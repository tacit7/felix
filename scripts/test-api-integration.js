#!/usr/bin/env node

/**
 * Test script for Phoenix Backend API integration
 * Run with: node test-api-integration.js
 */

const API_BASE = 'http://localhost:4001';

// ANSI color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m'
};

// Test utilities
const log = {
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  info: (msg) => console.log(`${colors.cyan}ℹ${colors.reset} ${msg}`),
  section: (msg) => console.log(`\n${colors.yellow}== ${msg} ==${colors.reset}`)
};

// Store auth token for authenticated requests
let authToken = null;

// Helper function to make API requests
async function apiRequest(endpoint, options = {}) {
  const url = `${API_BASE}${endpoint}`;
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers
  };
  
  if (authToken && !options.skipAuth) {
    headers['Authorization'] = `Bearer ${authToken}`;
  }
  
  try {
    const response = await fetch(url, {
      ...options,
      headers
    });
    
    let data;
    try {
      data = await response.json();
    } catch (parseError) {
      // If JSON parsing fails, return error without consuming body again
      data = { error: 'Invalid JSON response', parseError: parseError.message };
    }
    
    return { ok: response.ok, status: response.status, data };
  } catch (error) {
    console.error('API Request Error:', error);
    console.error('URL:', url);
    console.error('Options:', options);
    return { ok: false, error: error.message };
  }
}

// Test functions
async function testHealthEndpoint() {
  log.section('Testing Health Endpoint');
  const result = await apiRequest('/api/health');
  
  if (result.ok) {
    log.success(`Health check passed: ${result.data.message}`);
    log.info(`Version: ${result.data.version}`);
  } else {
    log.error(`Health check failed: ${result.error || result.data.error}`);
  }
  
  return result.ok;
}

async function testRegistration() {
  log.section('Testing User Registration');
  
  const testUser = {
    username: `testuser_${Date.now()}`,
    password: 'TestPassword123!',
    email: `test_${Date.now()}@example.com`,
    full_name: 'Test User'
  };
  
  const result = await apiRequest('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify(testUser)
  });
  
  if (result.ok && result.data.success) {
    log.success(`Registration successful for ${testUser.username}`);
    log.info(`User ID: ${result.data.user.id}`);
    authToken = result.data.token;
    return { success: true, user: testUser };
  } else {
    log.error(`Registration failed: ${result.data.error || result.data.message}`);
    return { success: false };
  }
}

async function testLogin(username, password) {
  log.section('Testing User Login');
  
  const result = await apiRequest('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ username, password })
  });
  
  if (result.ok && result.data.success) {
    log.success(`Login successful for ${username}`);
    authToken = result.data.token;
    return true;
  } else {
    log.error(`Login failed: ${result.data.error || result.data.message}`);
    return false;
  }
}

async function testAuthenticatedEndpoint() {
  log.section('Testing Authenticated Endpoint (/api/auth/me)');
  
  if (!authToken) {
    log.error('No auth token available');
    return false;
  }
  
  const result = await apiRequest('/api/auth/me');
  
  if (result.ok && result.data.success) {
    log.success('Authentication verified');
    log.info(`User: ${result.data.user.username} (${result.data.user.email})`);
    return true;
  } else {
    log.error(`Authentication failed: ${result.data.error || 'Invalid token'}`);
    return false;
  }
}

async function testPlacesSearch() {
  log.section('Testing Places Search API (Requires Google API Key)');
  
  const searchParams = new URLSearchParams({
    query: 'coffee',
    lat: '34.0522', // Los Angeles latitude  
    lng: '-118.2437', // Los Angeles longitude
    radius: '1000'
  });
  
  const result = await apiRequest(`/api/places/search?${searchParams}`);
  
  if (result.ok) {
    log.success('Places search successful');
    log.info(`Found ${result.data.results?.length || 0} places`);
    if (result.data.results?.length > 0) {
      log.info(`First result: ${result.data.results[0].name}`);
    }
    return true;
  } else {
    log.error(`Places search failed: ${result.data.error || result.data.message || 'Google API key required'}`);
    log.info('ℹ Note: This endpoint requires GOOGLE_PLACES_API_KEY environment variable');
    return false;
  }
}

async function testRouteCalculation() {
  log.section('Testing Route Calculation API (Requires Google API Key)');
  
  const routeData = {
    origin: 'Los Angeles, CA',
    destination: 'San Francisco, CA',
    waypoints: []
  };
  
  const result = await apiRequest('/api/routes/calculate', {
    method: 'POST',
    body: JSON.stringify(routeData)
  });
  
  if (result.ok && result.data.data) {
    log.success('Route calculation successful');
    log.info(`Distance: ${result.data.data.distance}`);
    log.info(`Duration: ${result.data.data.duration}`);
    return true;
  } else {
    log.error(`Route calculation failed: ${result.data.error || result.data.message || 'Google API key required'}`);
    log.info('ℹ Note: This endpoint requires GOOGLE_DIRECTIONS_API_KEY environment variable');
    return false;
  }
}

async function testInterestsCategories() {
  log.section('Testing Interest Categories API');
  
  const result = await apiRequest('/api/interests/categories');
  
  if (result.ok) {
    log.success('Interest categories retrieved successfully');
    log.info(`Found ${result.data.data?.length || 0} categories`);
    if (result.data.data?.length > 0) {
      log.info(`First category: ${result.data.data[0].name}`);
    }
    return true;
  } else {
    log.error(`Interest categories failed: ${result.data.error || result.data.message}`);
    return false;
  }
}

async function testPublicTrips() {
  log.section('Testing Public Trips API');
  
  const result = await apiRequest('/api/trips/public');
  
  if (result.ok) {
    log.success('Public trips retrieved successfully');
    log.info(`Found ${result.data.data?.length || 0} public trips`);
    if (result.data.data?.length > 0) {
      log.info(`First trip: ${result.data.data[0].name}`);
    }
    return true;
  } else {
    log.error(`Public trips failed: ${result.data.error || result.data.message}`);
    return false;
  }
}

async function testTripCreation() {
  log.section('Testing Trip Creation (Authenticated)');
  
  if (!authToken) {
    log.error('No auth token available');
    return false;
  }
  
  const tripData = {
    trip: {
      title: 'Test Road Trip',
      start_city: 'Los Angeles, CA',
      end_city: 'San Francisco, CA',
      is_public: true
    }
  };
  
  const result = await apiRequest('/api/trips', {
    method: 'POST',
    body: JSON.stringify(tripData)
  });
  
  if (result.ok) {
    // Phoenix controllers typically return the data directly, not wrapped in success
    if (result.data.data && result.data.data.id) {
      log.success('Trip created successfully');
      log.info(`Trip ID: ${result.data.data.id}`);
      return true;
    } else if (result.data.success) {
      log.success('Trip created successfully');
      log.info(`Trip ID: ${result.data.trip?.id || 'Unknown'}`);
      return true;
    } else {
      log.error(`Trip creation failed: ${result.data.error || result.data.message || 'Unknown error'}`);
      log.error(`Full response: ${JSON.stringify(result.data)}`);
      return false;
    }
  } else {
    log.error(`Trip creation HTTP error: ${result.status || 'Unknown status'}`);
    if (result.data) {
      log.error(`Response: ${JSON.stringify(result.data)}`);
    }
    return false;
  }
}

async function testCORS() {
  log.section('Testing CORS Configuration');
  
  try {
    const response = await fetch(`${API_BASE}/api/health`, {
      method: 'OPTIONS',
      headers: {
        'Origin': 'http://localhost:3001',
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'content-type'
      }
    });
    
    const corsHeaders = {
      'access-control-allow-origin': response.headers.get('access-control-allow-origin'),
      'access-control-allow-methods': response.headers.get('access-control-allow-methods'),
      'access-control-allow-headers': response.headers.get('access-control-allow-headers'),
      'access-control-allow-credentials': response.headers.get('access-control-allow-credentials')
    };
    
    if (corsHeaders['access-control-allow-origin']) {
      log.success('CORS is properly configured');
      log.info(`Allowed origin: ${corsHeaders['access-control-allow-origin']}`);
      log.info(`Allowed methods: ${corsHeaders['access-control-allow-methods']}`);
      log.info(`Credentials allowed: ${corsHeaders['access-control-allow-credentials']}`);
      return true;
    } else {
      log.error('CORS headers not found');
      return false;
    }
  } catch (error) {
    log.error(`CORS test failed: ${error.message}`);
    return false;
  }
}

// Main test runner
async function runTests() {
  console.log(`${colors.cyan}═══════════════════════════════════════════`);
  console.log(`${colors.cyan}   Phoenix Backend API Integration Test    `);
  console.log(`${colors.cyan}═══════════════════════════════════════════${colors.reset}`);
  
  const results = {
    total: 0,
    passed: 0,
    failed: 0
  };
  
  // Run tests in sequence
  const tests = [
    { name: 'Health Check', fn: testHealthEndpoint },
    { name: 'CORS Configuration', fn: testCORS },
    { name: 'User Registration', fn: testRegistration },
    { name: 'Authenticated Endpoint', fn: testAuthenticatedEndpoint },
    { name: 'Interest Categories', fn: testInterestsCategories },
    { name: 'Public Trips', fn: testPublicTrips },
    { name: 'Trip Creation', fn: testTripCreation },
    { name: 'Places Search', fn: testPlacesSearch },
    { name: 'Route Calculation', fn: testRouteCalculation }
  ];
  
  for (const test of tests) {
    results.total++;
    try {
      const passed = await test.fn();
      if (passed) {
        results.passed++;
      } else {
        results.failed++;
      }
    } catch (error) {
      log.error(`${test.name} threw an error: ${error.message}`);
      results.failed++;
    }
  }
  
  // Summary
  log.section('Test Summary');
  console.log(`Total tests: ${results.total}`);
  console.log(`${colors.green}Passed: ${results.passed}${colors.reset}`);
  console.log(`${colors.red}Failed: ${results.failed}${colors.reset}`);
  
  if (results.failed === 0) {
    console.log(`\n${colors.green}All tests passed! ✨${colors.reset}`);
  } else {
    console.log(`\n${colors.red}Some tests failed. Please check the errors above.${colors.reset}`);
  }
}

// Run the tests
runTests().catch(console.error);