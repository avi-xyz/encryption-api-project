# Authentication Testing Guide

This guide explains how to test the authentication and authorization features of the Encryption API.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Local Testing Setup](#local-testing-setup)
3. [Testing Without Cognito (Development Mode)](#testing-without-cognito)
4. [Testing With Cognito (Production Mode)](#testing-with-cognito)
5. [Test Scenarios](#test-scenarios)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required
- Java 17+
- Maven 3.6+
- MySQL 8.0+ (or Docker with MySQL)

### For Production Testing
- AWS Account with Cognito User Pool deployed
- AWS CLI configured
- User registered in Cognito

---

## Local Testing Setup

### 1. Start MySQL Database

**Option A: Using Docker**
```bash
docker run --name encryption-mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=encryption_db \
  -e MYSQL_USER=encryptuser \
  -e MYSQL_PASSWORD=encryptpass \
  -p 3306:3306 \
  -d mysql:8.0
```

**Option B: Using Local MySQL**
```bash
mysql -u root -p

CREATE DATABASE encryption_db;
CREATE USER 'encryptuser'@'localhost' IDENTIFIED BY 'encryptpass';
GRANT ALL PRIVILEGES ON encryption_db.* TO 'encryptuser'@'localhost';
FLUSH PRIVILEGES;
```

### 2. Run Database Migrations

Flyway migrations will run automatically on application startup, creating:
- `users` table
- `encrypted_data` table with `user_id` column
- `api_audit_log` table
- `api_keys` table
- System user for existing data

### 3. Set Environment Variables

For local development, you can skip Cognito by not setting these variables (authentication will be disabled):

```bash
# Optional - only if you want to test with real Cognito
export AWS_REGION=us-east-1
export COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
export COGNITO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxx
```

---

## Testing Without Cognito

For local development without Cognito, you'll need to temporarily disable security:

### Option 1: Disable Security for Testing

Create a test security configuration:

```java
// src/main/java/com/aviencryption/config/TestSecurityConfig.java
@Profile("test")
@Configuration
@EnableWebSecurity
public class TestSecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        return http.build();
    }
}
```

Run with test profile:
```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=test
```

### Option 2: Create Mock User for Testing

Add a test endpoint that creates a mock authentication:

```java
// For testing only - DO NOT deploy to production
@RestController
@RequestMapping("/test")
@Profile("local")
public class TestAuthController {

    @GetMapping("/mock-encrypt")
    public ResponseEntity<?> mockEncrypt(@RequestParam String plainText) {
        // Create mock user
        User mockUser = User.builder()
            .id("test-user-123")
            .email("test@example.com")
            .fullName("Test User")
            .build();

        // Call service with mock user
        Long id = encryptionService.encryptAndStore(plainText, mockUser.getId());
        return ResponseEntity.ok(Map.of("id", id));
    }
}
```

---

## Testing With Cognito

### 1. Deploy Cognito Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

Note the outputs:
- `cognito_user_pool_id`
- `cognito_client_id`
- `cognito_user_pool_endpoint`

### 2. Create Test User in Cognito

```bash
# Set variables
USER_POOL_ID="us-east-1_XXXXXXXXX"
CLIENT_ID="xxxxxxxxxxxxxxxxxxxxx"

# Create user
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username testuser@example.com \
  --password MySecurePass123! \
  --permanent
```

### 3. Get JWT Token

```bash
# Authenticate and get tokens
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=testuser@example.com,PASSWORD=MySecurePass123! \
  --query 'AuthenticationResult.IdToken' \
  --output text
```

Save the token - you'll use it in the `Authorization` header.

### 4. Start Application

```bash
export AWS_REGION=us-east-1
export COGNITO_USER_POOL_ID=$USER_POOL_ID
export COGNITO_CLIENT_ID=$CLIENT_ID

./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

---

## Test Scenarios

### Scenario 1: Health Check (No Authentication Required)

```bash
curl http://localhost:8080/api/health
```

**Expected Response (200 OK):**
```json
{
  "status": "UP",
  "timestamp": "2026-01-07T15:00:00"
}
```

---

### Scenario 2: Encrypt Without JWT Token (Should Fail)

```bash
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText": "my secret message"}'
```

**Expected Response (401 Unauthorized):**
```json
{
  "timestamp": "2026-01-07T15:00:00",
  "status": 401,
  "error": "Unauthorized",
  "message": "Authentication required",
  "path": "/api/encrypt"
}
```

---

### Scenario 3: Encrypt With Valid JWT Token (Should Succeed)

```bash
# Get token first (see step 3 above)
TOKEN="eyJraWQiOiJxxx..."

curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"plainText": "my secret message"}'
```

**Expected Response (201 Created):**
```json
{
  "id": 1,
  "message": "Data encrypted and stored successfully",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-01-07T15:00:00"
}
```

**Database Check:**
```sql
SELECT id, user_id, created_at FROM encrypted_data WHERE id = 1;
SELECT id, user_id, created_at FROM users;
SELECT user_id, action, status, created_at FROM api_audit_log ORDER BY created_at DESC LIMIT 5;
```

---

### Scenario 4: Decrypt Own Data (Should Succeed)

```bash
curl http://localhost:8080/api/decrypt/1 \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Response (200 OK):**
```json
{
  "id": 1,
  "plainText": "my secret message",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-01-07T15:00:00"
}
```

---

### Scenario 5: Decrypt Someone Else's Data (Should Fail)

1. Create another user and get their token
2. Try to decrypt user 1's data with user 2's token

```bash
TOKEN_USER2="eyJraWQiOiJyyy..."

curl http://localhost:8080/api/decrypt/1 \
  -H "Authorization: Bearer $TOKEN_USER2"
```

**Expected Response (404 Not Found):**
```json
{
  "timestamp": "2026-01-07T15:00:00",
  "status": 404,
  "error": "Not Found",
  "message": "EncryptedData with ID 1 was not found",
  "path": "/api/decrypt/1"
}
```

**Security Check:**
```sql
-- Should see UNAUTHORIZED status
SELECT user_id, action, status, resource_id, created_at
FROM api_audit_log
WHERE status = 'UNAUTHORIZED'
ORDER BY created_at DESC;
```

---

### Scenario 6: Invalid/Expired JWT Token

```bash
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer INVALID_TOKEN" \
  -d '{"plainText": "test"}'
```

**Expected Response (401 Unauthorized):**
```json
{
  "timestamp": "2026-01-07T15:00:00",
  "status": 401,
  "error": "Unauthorized",
  "message": "Authentication required",
  "path": "/api/encrypt"
}
```

---

### Scenario 7: JIT User Provisioning

On first login, a user should be automatically created:

```bash
# Use token for a brand new user
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $NEW_USER_TOKEN" \
  -d '{"plainText": "first message"}'
```

**Database Check:**
```sql
-- Should see new user created
SELECT id, cognito_user_id, email, full_name, created_at, last_login_at
FROM users
ORDER BY created_at DESC
LIMIT 1;
```

**Log Check:**
```
INFO  c.a.s.JwtAuthenticationFilter - Created new user on first login: newuser@example.com (UUID)
```

---

## Troubleshooting

### Issue: "Authentication required" despite valid token

**Check 1: Token Format**
```bash
# Token should start with "eyJ"
echo $TOKEN | cut -c1-3
# Output: eyJ
```

**Check 2: Token Not Expired**
```bash
# Decode token (use https://jwt.io or)
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null
# Check "exp" claim
```

**Check 3: Cognito Configuration**
```bash
# Verify environment variables
echo $COGNITO_USER_POOL_ID
echo $COGNITO_CLIENT_ID
echo $AWS_REGION
```

**Check 4: Application Logs**
```bash
# Look for JWT validation errors
tail -f logs/spring.log | grep -i "jwt\|cognito\|authentication"
```

---

### Issue: Database connection errors

**Check MySQL**
```bash
# Test connection
mysql -u encryptuser -pencryptpass -h localhost encryption_db -e "SELECT 1;"
```

**Check Application Properties**
```bash
# Verify datasource configuration
cat src/main/resources/application-local.yml | grep -A5 datasource
```

---

### Issue: Flyway migration errors

**Check Migration Files**
```bash
ls -la src/main/resources/db/migration/
```

**Reset Database (Development Only)**
```bash
mysql -u encryptuser -pencryptpass encryption_db < /dev/null

DROP DATABASE encryption_db;
CREATE DATABASE encryption_db;
```

Then restart application to rerun migrations.

---

### Issue: User created but can't decrypt own data

**Check User ID Matching**
```sql
-- Compare user_id in encrypted_data vs users table
SELECT
    ed.id,
    ed.user_id as data_user_id,
    u.id as user_id,
    u.cognito_user_id,
    u.email
FROM encrypted_data ed
LEFT JOIN users u ON ed.user_id = u.id;
```

**Check Logs**
```
WARN c.a.s.EncryptionService - User X attempted to access encrypted data Y owned by Z
```

---

## Performance Testing

### Load Test with Apache Bench

```bash
# Get token
TOKEN="eyJraWQiOiJxxx..."

# Create request body file
echo '{"plainText":"load test message"}' > /tmp/request.json

# Run 100 requests with 10 concurrent
ab -n 100 -c 10 \
  -p /tmp/request.json \
  -T "application/json" \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/encrypt
```

**Check Audit Logs Performance**
```sql
-- Async audit logging should not slow down requests
SELECT
    COUNT(*) as total_requests,
    AVG(execution_time_ms) as avg_time_ms,
    MAX(execution_time_ms) as max_time_ms,
    MIN(execution_time_ms) as min_time_ms
FROM api_audit_log
WHERE created_at > NOW() - INTERVAL 1 HOUR;
```

---

## Security Checklist

- [ ] JWT tokens expire after 60 minutes
- [ ] Invalid tokens return 401 Unauthorized
- [ ] Users can only decrypt their own data
- [ ] Unauthorized access attempts are logged
- [ ] Health endpoint is public (no auth required)
- [ ] All other endpoints require authentication
- [ ] User IDs are UUIDs (not sequential)
- [ ] Audit logs capture IP address and user agent
- [ ] Database has foreign key constraints
- [ ] No sensitive data in logs (tokens, passwords, plaintext)

---

## Next Steps

After validating authentication locally:

1. **Deploy to AWS Lambda**: Update Terraform to include Cognito outputs as Lambda environment variables
2. **Configure API Gateway**: Add Cognito authorizer to API Gateway
3. **Test End-to-End**: Test with real Cognito users through API Gateway
4. **Monitor**: Set up CloudWatch dashboards for auth failures
5. **Rotate Keys**: Test API key rotation Lambda function
