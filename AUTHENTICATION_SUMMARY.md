# Authentication & Authorization Implementation Summary

## Overview

Successfully implemented JWT-based authentication and authorization for the Encryption API using AWS Cognito. The implementation provides secure, multi-tenant data isolation with comprehensive audit logging.

---

## What Was Implemented

### 1. **Database Layer** ✅

#### New Tables
- **`users`** - Stores user accounts linked to Cognito identities
  - Fields: id (UUID), cognito_user_id, email, full_name, timestamps, is_active
  - Indexes: cognito_user_id, email, is_active

- **`api_audit_log`** - Complete audit trail of all operations
  - Fields: user_id, action, resource_id, ip_address, user_agent, status, execution_time_ms
  - Indexes: (user_id, action, created_at), created_at, status

- **`api_keys`** - API key rotation support
  - Fields: key_name, key_value, user_id, environment, is_active, expires_at
  - Automated 90-day rotation with Lambda

#### Modified Tables
- **`encrypted_data`** - Added user ownership
  - New field: `user_id VARCHAR(36) NOT NULL`
  - New index: (user_id, created_at)
  - Foreign key constraint to users table

#### Migration Files
- `V2__add_authentication_tables.sql` - Complete database schema for authentication

---

### 2. **Security Layer** ✅

#### Components Created

**CognitoJwtValidator** ([CognitoJwtValidator.java](src/main/java/com/aviencryption/security/CognitoJwtValidator.java))
- Validates JWT tokens from AWS Cognito
- Verifies RS256 signature using JWKS from Cognito
- Validates token expiration, issuer, and audience claims
- Caches public keys for performance
- Extracts user claims (sub, email, name)

**JwtAuthenticationFilter** ([JwtAuthenticationFilter.java](src/main/java/com/aviencryption/security/JwtAuthenticationFilter.java))
- Intercepts HTTP requests to extract JWT from Authorization header
- Validates tokens using CognitoJwtValidator
- **Just-In-Time (JIT) User Provisioning**: Automatically creates users on first login
- Updates user's last login timestamp and syncs email/name from Cognito
- Sets Spring Security authentication context

**UserAuthentication** ([UserAuthentication.java](src/main/java/com/aviencryption/security/UserAuthentication.java))
- Spring Security Authentication wrapper for User entity
- Implements Authentication interface
- Used with `@AuthenticationPrincipal` in controllers
- Provides ROLE_USER authority to all authenticated users

**SecurityConfig** ([SecurityConfig.java](src/main/java/com/aviencryption/security/SecurityConfig.java))
- Configures security filter chain
- Stateless session management (no cookies)
- Public endpoints: /api/health, /actuator/**
- Protected endpoints: /api/** (requires JWT)
- Custom 401/403 error responses

---

### 3. **Business Logic Updates** ✅

#### EncryptionService
**Updated Methods:**
- `encryptAndStore(String plainText, String userId)` - Now requires userId
- `decryptFromStore(Long id, String userId)` - Validates ownership

**Authorization Logic:**
- Checks if requesting user owns the encrypted data
- Returns 404 instead of 403 to prevent resource enumeration
- Logs unauthorized access attempts

#### EncryptionController
**Updated Endpoints:**
- All endpoints now inject `@AuthenticationPrincipal UserAuthentication`
- User ID automatically extracted from JWT token
- Responses include userId for tracking

**DTOs Updated:**
- `EncryptResponse` - Added userId field
- `DecryptResponse` - Added userId field

---

### 4. **Audit Logging** ✅

#### AuditService ([AuditService.java](src/main/java/com/aviencryption/service/AuditService.java))

**Features:**
- **Async Logging**: Uses `@Async` to not slow down API responses
- **Comprehensive Capture**: Records who, what, when, where, how, and result
- **Security Monitoring**: Special alerts for unauthorized access attempts

**Logged Information:**
- User ID
- Action (ENCRYPT, DECRYPT, etc.)
- Resource ID
- IP Address (handles X-Forwarded-For)
- User Agent
- HTTP Method and Path
- Status (SUCCESS, FAILURE, UNAUTHORIZED)
- Execution Time (milliseconds)
- Error Messages (truncated to 1000 chars)

**Methods:**
- `logEncryptSuccess(userId, resourceId, executionTimeMs)`
- `logEncryptFailure(userId, errorMessage, executionTimeMs)`
- `logDecryptSuccess(userId, resourceId, executionTimeMs)`
- `logDecryptUnauthorized(userId, resourceId, errorMessage)` - Security Alert!
- `logDecryptFailure(userId, resourceId, errorMessage)`

---

### 5. **Configuration** ✅

#### application.yml
```yaml
# Async support for audit logging
spring:
  task:
    execution:
      pool:
        core-size: 2
        max-size: 5
        queue-capacity: 100

# AWS Cognito
aws:
  cognito:
    region: ${AWS_REGION:us-east-1}
    user-pool-id: ${COGNITO_USER_POOL_ID:}
    client-id: ${COGNITO_CLIENT_ID:}
```

#### application-local.yml
- Test configuration with mock Cognito values
- DEBUG logging for development

#### application-prod.yml
- Cognito values from environment variables
- Validate-only mode for Flyway (no auto DDL)
- INFO/WARN logging levels

#### AsyncConfig.java
- Enables `@Async` annotation support
- Configures thread pool for audit logging

---

### 6. **Infrastructure (Terraform)** ✅

#### Cognito User Pool ([terraform/cognito.tf](terraform/cognito.tf))
```hcl
resource "aws_cognito_user_pool" "encryption_api"
  - Email-based authentication
  - Strong password policy (12 chars, all character types)
  - MFA support (optional)
  - Advanced security mode (ENFORCED)
  - Email verification required
  - 60-minute access token lifetime
  - 30-day refresh token lifetime
```

#### API Key Rotation ([terraform/api_keys.tf](terraform/api_keys.tf))
```hcl
- Primary/Secondary API key strategy
- 90-day rotation schedule
- Lambda function for automated rotation
- Keys stored in AWS Secrets Manager
```

---

### 7. **Exception Handling** ✅

**Custom Exceptions:**
- `JwtAuthenticationException` - 401 Unauthorized (JWT validation failures)
- `UnauthorizedException` - 403 Forbidden (authorization failures)
- `ResourceNotFoundException` - 404 Not Found (missing or unauthorized resources)

**GlobalExceptionHandler** ([GlobalExceptionHandler.java](src/main/java/com/aviencryption/exception/GlobalExceptionHandler.java))
- Centralized error handling
- Consistent JSON error responses
- Security-focused messages (no internal details leaked)
- Handles Spring Security exceptions

---

## Security Features

### Authentication
- [x] JWT tokens from AWS Cognito
- [x] RS256 signature verification
- [x] Token expiration validation
- [x] Issuer and audience validation
- [x] Bearer token format enforcement
- [x] Automatic user creation on first login (JIT provisioning)

### Authorization
- [x] Database-level user isolation (foreign keys)
- [x] Service-layer ownership checks
- [x] Returns 404 for unauthorized access (prevents enumeration)
- [x] No cross-user data access possible

### Audit & Monitoring
- [x] All operations logged asynchronously
- [x] IP address and user agent tracking
- [x] Execution time monitoring
- [x] Security alerts for unauthorized attempts
- [x] Tamper-proof append-only audit log

### Data Protection
- [x] AES-256-GCM encryption (unchanged)
- [x] Unique keys per record (unchanged)
- [x] Master key encryption (unchanged)
- [x] User ownership enforcement (new)

---

## API Changes

### Before (No Authentication)
```bash
# Encrypt
POST /api/encrypt
Content-Type: application/json

{"plainText": "secret"}

# Response
{"id": 1, "message": "...", "timestamp": "..."}
```

### After (With Authentication)
```bash
# Encrypt - Requires JWT
POST /api/encrypt
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6...
Content-Type: application/json

{"plainText": "secret"}

# Response
{"id": 1, "message": "...", "userId": "550e8400-...", "timestamp": "..."}
```

### New Security Behavior

**Scenario 1: No JWT Token**
```
Request: POST /api/encrypt (no Authorization header)
Response: 401 Unauthorized
```

**Scenario 2: Invalid/Expired JWT**
```
Request: POST /api/encrypt (with invalid token)
Response: 401 Unauthorized
```

**Scenario 3: Valid JWT, Own Data**
```
Request: GET /api/decrypt/1 (user owns data 1)
Response: 200 OK with plaintext
```

**Scenario 4: Valid JWT, Other User's Data**
```
Request: GET /api/decrypt/1 (user does NOT own data 1)
Response: 404 Not Found (same as if data didn't exist)
Audit: UNAUTHORIZED status logged with security alert
```

---

## Testing

### Local Testing (Without Cognito)

**1. Use Test Profile:**
```bash
# Start with test configuration (mock authentication)
./mvnw spring-boot:run -Dspring-boot.run.profiles=test
```

**2. Run Test Script:**
```bash
./test-authentication.sh
```

**3. Manual Testing:**
```bash
# Test with mock user
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "X-Test-User-Id: user-123" \
  -H "X-Test-User-Email: test@example.com" \
  -d '{"plainText": "test message"}'
```

### Production Testing (With Cognito)

**1. Deploy Cognito:**
```bash
cd terraform
terraform apply
# Note: user_pool_id, client_id
```

**2. Create Test User:**
```bash
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_XXXXXXXXX \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com \
  --temporary-password TempPass123!
```

**3. Get JWT Token:**
```bash
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id XXXXXXXXXXXXX \
  --auth-parameters USERNAME=testuser@example.com,PASSWORD=FinalPass123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)
```

**4. Test API:**
```bash
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"plainText": "secret message"}'
```

---

## File Structure

```
src/main/java/com/aviencryption/
├── config/
│   ├── AsyncConfig.java               # Enables async audit logging
│   └── TestSecurityConfig.java        # Test profile mock auth (DO NOT DEPLOY)
├── controller/
│   └── EncryptionController.java      # Updated with @AuthenticationPrincipal
├── exception/
│   ├── GlobalExceptionHandler.java    # Centralized error handling
│   ├── JwtAuthenticationException.java # 401 errors
│   ├── ResourceNotFoundException.java  # 404 errors
│   └── UnauthorizedException.java      # 403 errors
├── model/
│   ├── ApiAuditLog.java               # Audit log entity
│   ├── EncryptedData.java             # Updated with userId
│   └── User.java                       # User entity
├── repository/
│   ├── ApiAuditLogRepository.java     # Audit log data access
│   ├── EncryptedDataRepository.java   # Updated with user queries
│   └── UserRepository.java             # User data access
├── security/
│   ├── CognitoJwtValidator.java       # JWT validation
│   ├── JwtAuthenticationFilter.java   # Request interceptor
│   ├── SecurityConfig.java             # Security configuration
│   └── UserAuthentication.java         # Authentication wrapper
└── service/
    ├── AuditService.java               # Async audit logging
    └── EncryptionService.java          # Updated with ownership checks

src/main/resources/
├── application.yml                     # Base configuration
├── application-local.yml               # Local dev configuration
├── application-prod.yml                # Production configuration
└── db/migration/
    └── V2__add_authentication_tables.sql # Database migration

terraform/
├── cognito.tf                          # Cognito User Pool
├── api_keys.tf                         # API key rotation
└── lambda/
    └── api_key_rotation.py             # Rotation Lambda

Root Files:
├── TESTING_GUIDE.md                    # Comprehensive testing guide
├── test-authentication.sh              # Automated test script
└── AUTHENTICATION_SUMMARY.md           # This file
```

---

## Dependencies Added

```xml
<!-- Spring Security -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>

<!-- JWT Libraries -->
<dependency>
    <groupId>com.auth0</groupId>
    <artifactId>java-jwt</artifactId>
    <version>4.4.0</version>
</dependency>
<dependency>
    <groupId>com.auth0</groupId>
    <artifactId>jwks-rsa</artifactId>
    <version>0.22.1</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.12.3</version>
</dependency>
<dependency>
    <groupId>com.nimbusds</groupId>
    <artifactId>nimbus-jose-jwt</artifactId>
    <version>9.37.3</version>
</dependency>

<!-- Database Migration -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-mysql</artifactId>
</dependency>

<!-- Utilities -->
<dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-lang3</artifactId>
</dependency>
```

---

## Next Steps for Deployment

### 1. Database Setup
```bash
# Run Flyway migrations
./mvnw flyway:migrate

# Verify tables created
mysql -u encryptuser -p encryption_db -e "SHOW TABLES;"
```

### 2. Deploy Cognito
```bash
cd terraform
terraform init
terraform apply

# Save outputs
export COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
export COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id)
```

### 3. Update Lambda Configuration
Add environment variables to Lambda:
- `AWS_REGION`
- `COGNITO_USER_POOL_ID`
- `COGNITO_CLIENT_ID`
- `ENCRYPTION_MASTER_KEY`

### 4. Deploy Application
```bash
./mvnw clean package
# Deploy JAR to Lambda or EC2
```

### 5. Configure API Gateway
Add Cognito authorizer to API Gateway:
```hcl
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id          = aws_apigatewayv2_api.encryption_api.id
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name            = "cognito-authorizer"

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${var.user_pool_id}"
  }
}
```

### 6. Test End-to-End
1. Create Cognito user
2. Get JWT token
3. Call API through API Gateway
4. Verify audit logs in database
5. Test unauthorized access scenarios

---

## Monitoring & Maintenance

### Key Metrics to Monitor
- Authentication failures (401 errors)
- Authorization failures (403/404 from audit log)
- JWT validation errors
- User creation rate (JIT provisioning)
- Audit log growth rate
- API key rotation success

### Database Queries for Monitoring

**User Growth:**
```sql
SELECT DATE(created_at) as date, COUNT(*) as new_users
FROM users
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

**Security Events:**
```sql
SELECT user_id, action, COUNT(*) as attempts
FROM api_audit_log
WHERE status = 'UNAUTHORIZED'
AND created_at > NOW() - INTERVAL 24 HOUR
GROUP BY user_id, action
ORDER BY attempts DESC;
```

**API Usage by User:**
```sql
SELECT u.email, a.action, COUNT(*) as count, AVG(a.execution_time_ms) as avg_time
FROM api_audit_log a
JOIN users u ON a.user_id = u.id
WHERE a.created_at > NOW() - INTERVAL 7 DAY
GROUP BY u.email, a.action
ORDER BY count DESC;
```

---

## Security Checklist

- [x] JWT signature verification with RS256
- [x] Token expiration validation
- [x] Issuer and audience verification
- [x] Stateless sessions (no cookies)
- [x] CSRF protection disabled (stateless API)
- [x] Database-level user isolation
- [x] Application-level authorization checks
- [x] 404 instead of 403 (prevents enumeration)
- [x] Comprehensive audit logging
- [x] IP address tracking
- [x] Security alerts for unauthorized access
- [x] No sensitive data in logs
- [x] API key rotation (90 days)
- [x] Master key from environment variable
- [x] Foreign key constraints for data integrity
- [x] Async audit logging (no performance impact)

---

## Conclusion

The Encryption API now has production-ready authentication and authorization using AWS Cognito with JWT tokens. Key features include:

✅ **Secure**: RS256 JWT validation, user isolation, audit logging
✅ **Scalable**: Stateless design, async logging, connection pooling
✅ **Observable**: Comprehensive audit logs with security alerts
✅ **User-Friendly**: JIT provisioning, automatic user sync from Cognito
✅ **Maintainable**: Clean separation of concerns, well-documented

The implementation follows security best practices and is ready for production deployment after completing the testing phase.
