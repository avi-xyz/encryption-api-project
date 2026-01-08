# Quick Start Guide - Authentication Testing

## Option 1: Quick Test (No Database Required)

If you just want to verify the code compiles and see the structure:

```bash
# Compile the project
./mvnw clean compile

# Review the implementation
cat AUTHENTICATION_SUMMARY.md
```

---

## Option 2: Local Test with Mock Authentication (No Cognito)

This is the fastest way to test the authentication features without setting up AWS Cognito.

### Prerequisites
- Java 17+
- Maven 3.6+
- MySQL 8.0+ (Docker recommended)

### Step 1: Start MySQL Database

```bash
# Using Docker (recommended)
docker run --name encryption-mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=encryption_db \
  -e MYSQL_USER=encryptuser \
  -e MYSQL_PASSWORD=encryptpass \
  -p 3306:3306 \
  -d mysql:8.0

# Wait for MySQL to start (about 10 seconds)
sleep 10
```

### Step 2: Start Application with Test Profile

```bash
# Test profile uses mock authentication (no Cognito required)
./mvnw spring-boot:run -Dspring-boot.run.profiles=test
```

**What this does:**
- Starts the application on port 8080
- Runs Flyway migrations (creates all tables)
- Uses `TestSecurityConfig` for mock authentication
- All requests get a mock user automatically

### Step 3: Run Automated Tests

```bash
# In a new terminal window
./test-authentication.sh
```

**Expected Output:**
```
================================
Authentication Testing Script
================================

✓ PASS: Health Check (No Auth)
✓ PASS: Encrypt with user-1
✓ PASS: Decrypt own data (user-1)
✓ PASS: Decrypt other user's data (user-2 trying to access user-1's data)
✓ PASS: Created 3 records for user-1
✓ PASS: Validation - Empty plainText
✓ PASS: Validation - Missing plainText field

✓ All critical tests passed!
```

### Step 4: Manual Testing

```bash
# Encrypt data for user-1
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "X-Test-User-Id: user-1" \
  -H "X-Test-User-Email: user1@example.com" \
  -d '{"plainText": "My secret message"}'

# Expected response:
# {
#   "id": 1,
#   "message": "Data encrypted and stored successfully",
#   "userId": "user-1",
#   "timestamp": "2026-01-07T..."
# }

# Decrypt the data (as user-1)
curl http://localhost:8080/api/decrypt/1 \
  -H "X-Test-User-Id: user-1" \
  -H "X-Test-User-Email: user1@example.com"

# Expected response:
# {
#   "id": 1,
#   "plainText": "My secret message",
#   "userId": "user-1",
#   "timestamp": "2026-01-07T..."
# }

# Try to decrypt as different user (should fail with 404)
curl http://localhost:8080/api/decrypt/1 \
  -H "X-Test-User-Id: user-2" \
  -H "X-Test-User-Email: user2@example.com"

# Expected response:
# {
#   "timestamp": "2026-01-07T...",
#   "status": 404,
#   "error": "Not Found",
#   "message": "EncryptedData with ID 1 was not found",
#   "path": "/api/decrypt/1"
# }
```

### Step 5: Check Database

```bash
# Connect to MySQL
docker exec -it encryption-mysql mysql -u encryptuser -pencryptpass encryption_db

# Or if using local MySQL:
# mysql -u encryptuser -pencryptpass encryption_db
```

```sql
-- View users created
SELECT id, email, cognito_user_id, created_at, last_login_at
FROM users
ORDER BY created_at DESC;

-- View encrypted data with owners
SELECT id, user_id, created_at
FROM encrypted_data
ORDER BY created_at DESC;

-- View audit logs
SELECT user_id, action, status, resource_id, ip_address, created_at
FROM api_audit_log
ORDER BY created_at DESC
LIMIT 20;

-- Check for security violations
SELECT user_id, action, resource_id, error_message, created_at
FROM api_audit_log
WHERE status = 'UNAUTHORIZED'
ORDER BY created_at DESC;
```

### Step 6: Cleanup

```bash
# Stop the application (Ctrl+C)

# Stop and remove MySQL container
docker stop encryption-mysql
docker rm encryption-mysql
```

---

## Option 3: Full Test with AWS Cognito

For testing with real AWS Cognito (production-like environment).

### Prerequisites
- AWS Account
- AWS CLI configured
- Terraform installed
- All from Option 2

### Step 1: Deploy Cognito

```bash
cd terraform

# Initialize Terraform
terraform init

# Deploy Cognito User Pool
terraform apply

# Save the outputs
export COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
export COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id)
export AWS_REGION=us-east-1

echo "User Pool ID: $COGNITO_USER_POOL_ID"
echo "Client ID: $COGNITO_CLIENT_ID"

cd ..
```

### Step 2: Create Test User

```bash
# Create user
aws cognito-idp admin-create-user \
  --user-pool-id $COGNITO_USER_POOL_ID \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com Name=name,Value="Test User" \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id $COGNITO_USER_POOL_ID \
  --username testuser@example.com \
  --password MySecurePass123! \
  --permanent

echo "User created: testuser@example.com / MySecurePass123!"
```

### Step 3: Get JWT Token

```bash
# Authenticate and get JWT token
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $COGNITO_CLIENT_ID \
  --auth-parameters USERNAME=testuser@example.com,PASSWORD=MySecurePass123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

echo "Token obtained (first 50 chars): ${TOKEN:0:50}..."
```

### Step 4: Start Application with Cognito

```bash
# Start with local profile (requires Cognito env vars)
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

### Step 5: Test with Real JWT

```bash
# Test encryption with JWT
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"plainText": "Message from real Cognito user"}'

# Expected: 201 Created with encrypted data ID

# Test decryption
curl http://localhost:8080/api/decrypt/1 \
  -H "Authorization: Bearer $TOKEN"

# Expected: 200 OK with plaintext
```

### Step 6: Test JWT Validation

```bash
# Test with no token (should fail)
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText": "test"}'

# Expected: 401 Unauthorized

# Test with invalid token (should fail)
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer INVALID_TOKEN" \
  -d '{"plainText": "test"}'

# Expected: 401 Unauthorized

# Test with expired token (should fail)
# Wait for token to expire (60 minutes by default)
# Or create a token with short expiration for testing
```

### Step 7: Test Multi-User Scenario

```bash
# Create second user
aws cognito-idp admin-create-user \
  --user-pool-id $COGNITO_USER_POOL_ID \
  --username user2@example.com \
  --user-attributes Name=email,Value=user2@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

aws cognito-idp admin-set-user-password \
  --user-pool-id $COGNITO_USER_POOL_ID \
  --username user2@example.com \
  --password MySecurePass123! \
  --permanent

# Get token for user 2
TOKEN2=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $COGNITO_CLIENT_ID \
  --auth-parameters USERNAME=user2@example.com,PASSWORD=MySecurePass123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

# User 1 encrypts data
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"plainText": "User 1 secret"}' | jq .

# User 2 tries to decrypt User 1's data (should fail with 404)
curl http://localhost:8080/api/decrypt/1 \
  -H "Authorization: Bearer $TOKEN2" | jq .

# Expected: 404 Not Found (prevents enumeration)

# Check audit log for security violation
docker exec -it encryption-mysql mysql -u encryptuser -pencryptpass encryption_db \
  -e "SELECT user_id, action, status, resource_id FROM api_audit_log WHERE status = 'UNAUTHORIZED';"
```

### Step 8: Cleanup

```bash
# Stop application (Ctrl+C)

# Stop MySQL
docker stop encryption-mysql
docker rm encryption-mysql

# Destroy Cognito (optional - will delete all users!)
cd terraform
terraform destroy
cd ..
```

---

## Troubleshooting

### Issue: "BUILD FAILURE" during compile

**Solution:** Check Java version
```bash
java -version  # Should be 17+
```

### Issue: MySQL connection refused

**Solution:** Check if MySQL is running
```bash
docker ps | grep mysql
# If not running, start it:
docker start encryption-mysql
```

### Issue: "Table 'users' doesn't exist"

**Solution:** Flyway migrations didn't run. Check logs:
```bash
# Look for Flyway migration logs
./mvnw spring-boot:run -Dspring-boot.run.profiles=test | grep -i flyway
```

### Issue: "Invalid JWT signature"

**Possible causes:**
1. Wrong COGNITO_USER_POOL_ID or COGNITO_CLIENT_ID
2. Token from different user pool
3. Token expired (check expiration time)

**Solution:**
```bash
# Verify environment variables
echo $COGNITO_USER_POOL_ID
echo $COGNITO_CLIENT_ID

# Get fresh token
TOKEN=$(aws cognito-idp initiate-auth ...)

# Decode token to check claims (use https://jwt.io)
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```

### Issue: Port 8080 already in use

**Solution:**
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or change port in application.yml
```

---

## What to Test

✅ **Basic Functionality:**
- [ ] Health endpoint works (no auth)
- [ ] Encrypt requires authentication
- [ ] Decrypt requires authentication
- [ ] Can decrypt own data
- [ ] Cannot decrypt others' data

✅ **JWT Validation:**
- [ ] No token = 401
- [ ] Invalid token = 401
- [ ] Expired token = 401
- [ ] Valid token = works

✅ **Data Isolation:**
- [ ] Users can only see their own data
- [ ] Unauthorized access returns 404 (not 403)
- [ ] Audit log records unauthorized attempts

✅ **JIT Provisioning:**
- [ ] New user auto-created on first login
- [ ] User email synced from Cognito
- [ ] Last login timestamp updated

✅ **Audit Logging:**
- [ ] All operations logged
- [ ] IP address captured
- [ ] Execution time recorded
- [ ] Security violations flagged

---

## Next Steps

After successful testing:

1. **Review Code**: Check [AUTHENTICATION_SUMMARY.md](AUTHENTICATION_SUMMARY.md) for implementation details

2. **Deploy to AWS**: Update Lambda/EC2 deployment with new dependencies and env vars

3. **Configure API Gateway**: Add Cognito authorizer

4. **Monitor**: Set up CloudWatch alerts for auth failures

5. **Document**: Update API documentation with authentication requirements

---

## Quick Reference

**Test Profile (Mock Auth):**
```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=test
```

**Local Profile (Real Cognito):**
```bash
export COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
export COGNITO_CLIENT_ID=XXXXXXXXXXXXX
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

**Get JWT Token:**
```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $COGNITO_CLIENT_ID \
  --auth-parameters USERNAME=user@example.com,PASSWORD=Pass123! \
  --query 'AuthenticationResult.IdToken' \
  --output text
```

**Test API:**
```bash
curl -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"plainText":"test"}' \
     http://localhost:8080/api/encrypt
```
