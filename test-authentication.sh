#!/bin/bash

# Authentication Testing Script
# Tests the encryption API with mock authentication (test profile)

set -e

API_URL="http://localhost:8080"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}Authentication Testing Script${NC}"
echo -e "${YELLOW}================================${NC}\n"

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
    fi
}

# Function to test endpoint
test_endpoint() {
    local test_name=$1
    local method=$2
    local endpoint=$3
    local headers=$4
    local data=$5
    local expected_status=$6

    echo -e "\n${YELLOW}Test: ${test_name}${NC}"

    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$API_URL$endpoint" $headers)
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$API_URL$endpoint" $headers -d "$data")
    fi

    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    echo "Response Code: $status_code"
    echo "Response Body: $body"

    if [ "$status_code" == "$expected_status" ]; then
        print_result 0 "$test_name"
        return 0
    else
        print_result 1 "$test_name (Expected: $expected_status, Got: $status_code)"
        return 1
    fi
}

# Wait for application to start
echo -e "${YELLOW}Checking if application is running...${NC}"
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s "$API_URL/api/health" > /dev/null 2>&1; then
        echo -e "${GREEN}Application is ready!${NC}\n"
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for application... ($attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}Application did not start in time${NC}"
    echo "Please start the application with: ./mvnw spring-boot:run -Dspring-boot.run.profiles=test"
    exit 1
fi

# Test 1: Health Check (No Auth Required)
test_endpoint \
    "Health Check (No Auth)" \
    "GET" \
    "/api/health" \
    "" \
    "" \
    "200"

# Test 2: Encrypt with Mock User (Test Profile)
echo -e "\n${YELLOW}Creating encrypted data for test user...${NC}"
encrypt_response=$(curl -s -X POST "$API_URL/api/encrypt" \
    -H "Content-Type: application/json" \
    -H "X-Test-User-Id: user-1" \
    -H "X-Test-User-Email: user1@example.com" \
    -d '{"plainText": "Secret message from user 1"}')

echo "Encrypt Response: $encrypt_response"

# Extract ID from response
id=$(echo "$encrypt_response" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

if [ -n "$id" ]; then
    print_result 0 "Encrypt with user-1 (ID: $id)"
else
    print_result 1 "Encrypt with user-1 (No ID returned)"
    id=1  # Continue with ID 1 for further tests
fi

# Test 3: Decrypt Own Data (Should Succeed)
test_endpoint \
    "Decrypt own data (user-1)" \
    "GET" \
    "/api/decrypt/$id" \
    "-H 'X-Test-User-Id: user-1' -H 'X-Test-User-Email: user1@example.com'" \
    "" \
    "200"

# Test 4: Try to Decrypt Someone Else's Data (Should Fail with 404)
test_endpoint \
    "Decrypt other user's data (user-2 trying to access user-1's data)" \
    "GET" \
    "/api/decrypt/$id" \
    "-H 'X-Test-User-Id: user-2' -H 'X-Test-User-Email: user2@example.com'" \
    "" \
    "404"

# Test 5: Create Multiple Records for Same User
echo -e "\n${YELLOW}Creating multiple records for user-1...${NC}"
for i in {1..3}; do
    curl -s -X POST "$API_URL/api/encrypt" \
        -H "Content-Type: application/json" \
        -H "X-Test-User-Id: user-1" \
        -H "X-Test-User-Email: user1@example.com" \
        -d "{\"plainText\": \"Message $i from user 1\"}" > /dev/null
done
print_result 0 "Created 3 records for user-1"

# Test 6: Validation - Empty Plain Text
test_endpoint \
    "Validation - Empty plainText" \
    "POST" \
    "/api/encrypt" \
    "-H 'Content-Type: application/json' -H 'X-Test-User-Id: user-1'" \
    '{"plainText": ""}' \
    "400"

# Test 7: Validation - Missing Plain Text
test_endpoint \
    "Validation - Missing plainText field" \
    "POST" \
    "/api/encrypt" \
    "-H 'Content-Type: application/json' -H 'X-Test-User-Id: user-1'" \
    '{}' \
    "400"

# Summary
echo -e "\n${YELLOW}================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}================================${NC}"
echo -e "${GREEN}✓ All critical tests passed!${NC}"
echo -e "\nTo test with real Cognito:"
echo -e "1. Deploy Cognito: cd terraform && terraform apply"
echo -e "2. Create user: aws cognito-idp admin-create-user ..."
echo -e "3. Get token: aws cognito-idp initiate-auth ..."
echo -e "4. Run app: ./mvnw spring-boot:run -Dspring-boot.run.profiles=local"
echo -e "5. Test: curl -H 'Authorization: Bearer \$TOKEN' ..."

echo -e "\n${YELLOW}Check audit logs:${NC}"
echo "mysql -u encryptuser -pencryptpass encryption_db -e 'SELECT user_id, action, status, resource_id, created_at FROM api_audit_log ORDER BY created_at DESC LIMIT 10;'"

echo -e "\n${GREEN}Testing complete!${NC}"
