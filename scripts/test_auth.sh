#!/bin/bash

echo "Testing JWT Authentication Flow..."

# 1. Test user registration
echo "1. Testing user registration..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:4001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser123",
    "password": "TestPassword123!",
    "email": "test@example.com",
    "full_name": "Test User"
  }')

echo "Register Response: $REGISTER_RESPONSE"

# Extract token from registration response (simple grep since jq not available)
TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo "Extracted Token: $TOKEN"

# 2. Test /api/auth/me with Bearer token
echo -e "\n2. Testing /api/auth/me with Bearer token..."
ME_RESPONSE=$(curl -s -X GET http://localhost:4001/api/auth/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "Me Response: $ME_RESPONSE"

# 3. Test /api/auth/me without token (should fail)
echo -e "\n3. Testing /api/auth/me without token (should fail)..."
NO_AUTH_RESPONSE=$(curl -s -X GET http://localhost:4001/api/auth/me \
  -H "Content-Type: application/json")

echo "No Auth Response: $NO_AUTH_RESPONSE"

echo -e "\nTest completed!"