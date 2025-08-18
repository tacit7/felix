#!/bin/bash

# OAuth Flow Verification Script
# This script verifies the Google OAuth flow endpoints are working correctly

echo "🔍 Google OAuth Flow Verification"
echo "=================================="
echo ""

BASE_URL="http://localhost:4001"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🏥 Step 1: Health Check"
health_status=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/api/health)
if [ "$health_status" = "200" ]; then
    echo -e "   ${GREEN}✅ Server is running (Status: $health_status)${NC}"
else
    echo -e "   ${RED}❌ Server not responding (Status: $health_status)${NC}"
    exit 1
fi
echo ""

echo "🚀 Step 2: OAuth Initiation (/api/auth/google)"
oauth_init_status=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/api/auth/google)
oauth_init_redirect=$(curl -s -w "%{redirect_url}" -o /dev/null $BASE_URL/api/auth/google)
if [ "$oauth_init_status" = "302" ] && [ "$oauth_init_redirect" = "$BASE_URL/auth/google" ]; then
    echo -e "   ${GREEN}✅ OAuth initiation working (302 → /auth/google)${NC}"
else
    echo -e "   ${RED}❌ OAuth initiation failed (Status: $oauth_init_status, Redirect: $oauth_init_redirect)${NC}"
fi
echo ""

echo "🔐 Step 3: Google OAuth Provider (/auth/google)"
google_oauth_status=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/auth/google)
google_oauth_url=$(curl -s -w "%{redirect_url}" -o /dev/null --max-redirs 0 $BASE_URL/auth/google 2>/dev/null || true)

if [ "$google_oauth_status" = "302" ]; then
    echo -e "   ${GREEN}✅ Google OAuth redirect working (Status: $google_oauth_status)${NC}"
    
    # Check if client_id is present
    if echo "$google_oauth_url" | grep -q "client_id=835274027919-"; then
        echo -e "   ${GREEN}✅ Client ID is present and correct${NC}"
    else
        echo -e "   ${RED}❌ Client ID missing or incorrect${NC}"
    fi
    
    # Check redirect URI
    if echo "$google_oauth_url" | grep -q "redirect_uri=http%3A%2F%2Flocalhost%3A4001%2Fauth%2Fgoogle%2Fcallback"; then
        echo -e "   ${GREEN}✅ Redirect URI is correct${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Redirect URI may be incorrect${NC}"
    fi
    
    # Check required parameters
    if echo "$google_oauth_url" | grep -q "response_type=code" && echo "$google_oauth_url" | grep -q "scope=email"; then
        echo -e "   ${GREEN}✅ OAuth parameters are correct${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Some OAuth parameters may be missing${NC}"
    fi
    
else
    echo -e "   ${RED}❌ Google OAuth redirect failed (Status: $google_oauth_status)${NC}"
fi
echo ""

echo "🌐 Step 4: OAuth Callback Endpoint Test"
callback_status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/auth/google/callback?code=test&state=test")
if [ "$callback_status" != "404" ]; then
    echo -e "   ${GREEN}✅ Callback endpoint exists (Status: $callback_status)${NC}"
    echo -e "   ${YELLOW}ℹ️  Note: Expected to redirect to /auth/error with test data${NC}"
else
    echo -e "   ${RED}❌ Callback endpoint not found (404)${NC}"
fi
echo ""

echo "📋 Summary"
echo "=========="
echo -e "Google OAuth URL: ${YELLOW}$google_oauth_url${NC}"
echo ""
echo "🔗 To test the complete flow:"
echo "1. Open browser and navigate to: $BASE_URL/api/auth/google"
echo "2. Complete Google OAuth process"
echo "3. Should redirect back to your frontend with auth success"
echo ""
echo "🚀 To start the server correctly (with .env file):"
echo "   dotenv mix phx.server"
echo ""
echo "📦 For automated testing, import the Postman collection:"
echo "   - Google_OAuth_Flow_Tests.postman_collection.json"
echo "   - Phoenix_Backend_OAuth.postman_environment.json"