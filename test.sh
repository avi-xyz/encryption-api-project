#!/bin/bash

echo "1. Health Check:"
curl http://localhost:8080/api/health
echo -e "\n"

echo "2. Encrypt:"
RESPONSE=$(curl -s -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText": "Test message"}')
echo $RESPONSE
echo -e "\n"

ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
echo "3. Decrypt ID $ID:"
curl http://localhost:8080/api/decrypt/$ID
echo -e "\n"
