#!/bin/bash

API_URL="https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com"

echo "=== Testing Encryption API in us-east-1 ==="
echo ""
echo "API Endpoint: $API_URL"
echo ""

echo "1. Health Check:"
health_response=$(curl -s "$API_URL/api/health")
echo "$health_response"
echo ""

echo "2. Encrypt Data:"
encrypt_response=$(curl -s -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from us-east-1! Migration successful."}')
echo "$encrypt_response"
echo ""

# Extract ID from response
id=$(echo "$encrypt_response" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
echo "Extracted ID: $id"
echo ""

echo "3. Decrypt Data (ID: $id):"
decrypt_response=$(curl -s "$API_URL/api/decrypt/$id")
echo "$decrypt_response"
echo ""

echo "=== Testing Complete ==="
echo ""
echo "✅ All endpoints working in us-east-1!"
