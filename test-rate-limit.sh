#!/bin/bash

API_URL="https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com"

echo "=== Testing Rate Limiting ==="
echo "Sending 7 requests rapidly to test burst limit (5 requests)..."
echo ""

for i in {1..7}; do
  echo "Request #$i:"
  response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$API_URL/api/health" 2>&1)
  http_code=$(echo "$response" | grep "HTTP_STATUS" | cut -d':' -f2)
  body=$(echo "$response" | grep -v "HTTP_STATUS")

  echo "  Status: $http_code"
  if [ "$http_code" = "429" ]; then
    echo "  ✅ RATE LIMITED (429 Too Many Requests)"
    echo "  Body: $body"
  elif [ "$http_code" = "200" ]; then
    echo "  ✅ Success (200 OK)"
  else
    echo "  Response: $body"
  fi
  echo ""

  # Small delay to simulate rapid requests
  sleep 0.1
done

echo "=== Rate Limit Test Complete ==="
echo ""
echo "Expected behavior:"
echo "  - Requests 1-5: Should return 200 OK"
echo "  - Request 6+: Should return 429 Too Many Requests"
echo ""
echo "Note: API Gateway may take a few seconds to enforce throttling."
