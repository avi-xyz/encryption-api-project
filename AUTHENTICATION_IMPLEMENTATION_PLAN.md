# Authentication & Authorization Implementation Plan

**Status**: 🚧 In Progress
**Date Started**: 2026-01-07
**Estimated Completion**: 2-3 weeks

---

## Overview

Adding JWT-based authentication with AWS Cognito to the Encryption API to ensure:
- ✅ User authentication (who you are)
- ✅ Data ownership (each user owns their encrypted keys)
- ✅ Authorization (can only access your own data)
- ✅ API key rotation mechanism
- ✅ Full audit trail

---

## Architecture

### Two-Layer Security Model

**Layer 1: API Gateway API Keys** (Service-level)
- Prevents anonymous access
- Rate limiting per API key
- Automatic rotation every 90 days
- Easy revocation

**Layer 2: JWT Tokens with AWS Cognito** (User-level)
- User identity management
- Per-user data isolation
- Fine-grained authorization
- OAuth 2.0 / OpenID Connect compliance

### Request Flow

```
┌─────────┐         ┌─────────────┐         ┌──────────┐         ┌─────────┐
│ Client  │────────>│ API Gateway │────────>│  Lambda  │────────>│   RDS   │
│         │  HTTPS  │ (Verify     │  JWT    │ (Verify  │  Query  │  MySQL  │
│         │         │  API Key)   │  Token  │  JWT +   │  User's │         │
│         │         │             │         │  Check   │  Data   │         │
│         │         │             │         │  Owner)  │         │         │
└─────────┘         └─────────────┘         └──────────┘         └─────────┘
                                                   │
                                                   v
                                            ┌──────────┐
                                            │ Cognito  │
                                            │ (Verify  │
                                            │  Token)  │
                                            └──────────┘
```

---

## ✅ Completed Tasks

### 1. Database Schema (DONE)

Created migration: `V2__add_authentication_tables.sql`

**New Tables:**
- `users` - User accounts linked to Cognito
- `api_audit_log` - Complete audit trail of all API operations
- `api_keys` - API key management with rotation
- `user_statistics` (view) - Aggregated user metrics

**Modified Tables:**
- `encrypted_data` - Added `user_id` column with foreign key constraint
- Created indexes for performance

**Key Features:**
- Automatic timestamps
- Soft deletes (is_active flag)
- Foreign key cascades for data integrity
- System user for orphaned records

### 2. AWS Cognito Infrastructure (DONE)

Created: `terraform/cognito.tf`

**Cognito User Pool:**
- Email-based authentication
- Strong password policy (12+ chars, mixed case, numbers, symbols)
- MFA support (optional)
- Advanced security mode (bot detection, compromised credentials)
- Token validity: 60 min access, 30 day refresh

**Outputs:**
- User Pool ID
- Client ID
- Hosted UI URL
- Stored in SSM Parameter Store

### 3. API Key Management (DONE)

Created: `terraform/api_keys.tf`

**Features:**
- Primary and secondary keys (for rotation)
- Stored in AWS Secrets Manager
- Automatic rotation via Lambda (every 90 days)
- EventBridge scheduled trigger

Created: `terraform/lambda/api_key_rotation.py`

**Rotation Strategy:**
1. Enable secondary key
2. Clients switch to secondary
3. Disable primary key
4. Create new primary key
5. Update secrets
6. Keep old key for 7-day rollback period

### 4. Dependencies (DONE)

Updated: `pom.xml`

**Added:**
- Spring Security (authentication framework)
- JWT libraries (Auth0 java-jwt, JJWT, Nimbus JOSE)
- JWK Provider (Cognito public key fetching)
- Flyway (database migrations)
- Apache Commons Lang (utilities)

---

## 🚧 In Progress / Pending Tasks

### Phase 1: Core Java Entities (Next)

**Need to create:**

1. **User Entity** (`src/main/java/com/aviencryption/model/User.java`)
   - Maps to `users` table
   - Links to Cognito sub claim
   - Tracks last login

2. **ApiAuditLog Entity** (`src/main/java/com/aviencryption/model/ApiAuditLog.java`)
   - Records all API operations
   - Tracks success/failure
   - Performance metrics

3. **ApiKey Entity** (`src/main/java/com/aviencryption/model/ApiKey.java`)
   - API key metadata
   - Usage tracking
   - Expiration management

4. **Update EncryptedData Entity**
   - Add `userId` field
   - Add relationship to User

**Repositories:**
- `UserRepository`
- `ApiAuditLogRepository`
- `ApiKeyRepository`

### Phase 2: Security Infrastructure

**Need to create:**

1. **JWT Authentication Filter** (`src/main/java/com/aviencryption/security/JwtAuthenticationFilter.java`)
   - Intercepts all requests
   - Extracts JWT from Authorization header
   - Verifies with Cognito public keys
   - Populates SecurityContext

2. **Cognito JWT Validator** (`src/main/java/com/aviencryption/security/CognitoJwtValidator.java`)
   - Fetches JWKS from Cognito
   - Validates signature
   - Checks expiration
   - Verifies issuer and audience

3. **Security Configuration** (`src/main/java/com/aviencryption/config/SecurityConfig.java`)
   - Configure Spring Security
   - Disable CSRF (stateless API)
   - Stateless session management
   - Permit health endpoint
   - Require authentication for all others

4. **User Authentication Principal** (`src/main/java/com/aviencryption/security/UserAuthentication.java`)
   - Custom Authentication object
   - Wraps User entity
   - Used with @AuthenticationPrincipal

### Phase 3: Business Logic Updates

**Need to update:**

1. **EncryptionService**
   - Add `userId` parameter to `encryptAndStore()`
   - Add ownership check to `decryptFromStore()`
   - Create `listUserData()` method
   - Throw `UnauthorizedException` for access violations

2. **EncryptionController**
   - Inject `@AuthenticationPrincipal User`
   - Pass `user.getId()` to service methods
   - Handle authorization exceptions
   - Add `/api/keys` endpoint to list user's data

3. **AuditService** (new)
   - Log all encrypt/decrypt operations
   - Capture IP address, user agent
   - Record execution time
   - Async logging for performance

4. **Exception Handlers**
   - `UnauthorizedException` - 403 Forbidden
   - `ResourceNotFoundException` - 404 Not Found
   - `JwtAuthenticationException` - 401 Unauthorized

### Phase 4: Authentication Endpoints

**Need to create:**

1. **AuthController** (`src/main/java/com/aviencryption/controller/AuthController.java`)
   - `POST /api/auth/register` - Helper to create Cognito user
   - `POST /api/auth/login` - Helper to authenticate with Cognito
   - `POST /api/auth/refresh` - Refresh access token
   - `POST /api/auth/logout` - Invalidate token (mark in audit log)

Note: Actual authentication is handled by Cognito, these are convenience endpoints.

### Phase 5: Configuration

**Need to update:**

1. **application.yml**
   ```yaml
   aws:
     cognito:
       region: ${AWS_REGION}
       user-pool-id: ${COGNITO_USER_POOL_ID}
       client-id: ${COGNITO_CLIENT_ID}

   spring:
     flyway:
       enabled: true
       locations: classpath:db/migration
       baseline-on-migrate: true
   ```

2. **application-local.yml**
   - Use test Cognito pool or mock authentication
   - Flyway migration for local MySQL

3. **application-prod.yml**
   - Production Cognito pool
   - SSM parameter resolution

### Phase 6: Testing

**Need to create:**

1. **Unit Tests**
   - `CognitoJwtValidatorTest`
   - `JwtAuthenticationFilterTest`
   - `EncryptionServiceTest` (with authorization)
   - Mock JWT tokens for testing

2. **Integration Tests**
   - `AuthenticationIntegrationTest`
   - Full flow: register → login → encrypt → decrypt
   - Test authorization failures
   - Test token expiration

3. **Testcontainers Updates**
   - Add Flyway migration execution
   - Create test users
   - Generate test JWT tokens

### Phase 7: Documentation

**Need to create:**

1. **AUTHENTICATION_GUIDE.md**
   - How to register/login
   - How to use JWT tokens
   - Token refresh flow
   - API key usage
   - Error handling

2. **Update README.md**
   - Add authentication section
   - Update API examples with JWT
   - Document security features

3. **API Examples**
   ```bash
   # Register user
   curl -X POST https://cognito-idp.us-east-1.amazonaws.com/ \
     -H "X-Amz-Target: AWSCognitoIdentityProviderService.SignUp" \
     -d '{"ClientId":"xxx","Username":"user@example.com","Password":"SecurePass123!"}'

   # Login
   curl -X POST https://cognito-idp.us-east-1.amazonaws.com/ \
     -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
     -d '{"AuthFlow":"USER_PASSWORD_AUTH","ClientId":"xxx","AuthParameters":{"USERNAME":"user@example.com","PASSWORD":"SecurePass123!"}}'

   # Use API (with JWT and API key)
   curl -X POST https://api.example.com/api/encrypt \
     -H "Authorization: Bearer eyJhbGc..." \
     -H "X-API-Key: your-api-key" \
     -H "Content-Type: application/json" \
     -d '{"plainText":"my secret"}'
   ```

4. **Update Postman Collection**
   - Add authentication folder
   - Pre-request scripts for token management
   - Environment variables for tokens
   - Automatic token refresh

---

## Database Migration Strategy

### Option 1: Fresh Start (CHOSEN)

Since you selected "start fresh":

1. ✅ Create system user in migration
2. ✅ Assign all existing records to system user
3. ✅ Make user_id NOT NULL after migration
4. ✅ Add foreign key constraint
5. New users will own their own data going forward

### Migration Execution

```bash
# Flyway will automatically run on application startup
./mvnw spring-boot:run -Dspring-boot.run.profiles=local

# Or manually
./mvnw flyway:migrate
```

---

## Security Features Summary

### Authentication
- ✅ AWS Cognito User Pool
- ✅ JWT tokens (RS256 signature)
- ✅ Token expiration (60 min)
- ✅ Refresh tokens (30 days)
- ✅ Password complexity requirements
- ✅ MFA support (optional)

### Authorization
- ✅ User-level data isolation
- ✅ Database-level foreign keys
- ✅ Service-level ownership checks
- ✅ Cannot access other users' data

### API Keys
- ✅ API Gateway key requirement
- ✅ Automatic rotation (90 days)
- ✅ Primary/secondary strategy
- ✅ Stored in Secrets Manager

### Audit Logging
- ✅ All encrypt/decrypt operations
- ✅ Success and failure tracking
- ✅ IP address capture
- ✅ User agent tracking
- ✅ Performance metrics

### Defense in Depth
1. **Network**: HTTPS/TLS encryption
2. **Service**: API Gateway + API keys
3. **Application**: JWT authentication
4. **Data**: User ownership + foreign keys
5. **Audit**: Complete operation logging

---

## API Changes

### Before (No Auth)

```bash
# Anyone can encrypt
curl -X POST https://api.example.com/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"secret"}'

# Anyone can decrypt anything
curl https://api.example.com/api/decrypt/1
```

### After (With Auth)

```bash
# Must provide API key + JWT token
curl -X POST https://api.example.com/api/encrypt \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "X-API-Key: your-api-gateway-key" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"secret"}'

# Returns 403 if trying to access someone else's data
curl https://api.example.com/api/decrypt/1 \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "X-API-Key: your-api-gateway-key"
```

### New Endpoints

```bash
# List my encrypted keys
GET /api/keys?page=0&size=20
Authorization: Bearer {jwt}
X-API-Key: {api-key}

# Get my user profile
GET /api/auth/profile
Authorization: Bearer {jwt}

# Health check (no auth required)
GET /api/health
```

---

## Cost Impact

### New AWS Resources

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| AWS Cognito | $0-5 | Free for first 50K MAU |
| API Gateway Keys | $0 | No additional cost |
| Lambda (rotation) | $0 | Runs every 90 days |
| Secrets Manager | $0.40 | $0.40/secret/month |
| **Total** | **~$0.40-5** | Minimal increase |

### Performance Impact

- JWT validation: ~5-10ms per request
- Database queries: No significant change (indexed)
- Overall: <1% performance impact

---

## Rollout Plan

### Phase 1: Deploy Infrastructure (Week 1)
1. Deploy Cognito via Terraform
2. Deploy API key rotation
3. Run database migrations
4. Verify infrastructure

### Phase 2: Deploy Application (Week 2)
1. Deploy Java code changes
2. Test authentication flow
3. Monitor logs
4. Fix any issues

### Phase 3: Documentation & Testing (Week 3)
1. Complete documentation
2. Update Postman collection
3. Create video tutorials (optional)
4. User acceptance testing

---

## Testing Checklist

- [ ] User can register in Cognito
- [ ] User can login and receive JWT
- [ ] JWT token is validated correctly
- [ ] Expired tokens are rejected
- [ ] User can encrypt data
- [ ] Encrypted data is linked to user
- [ ] User can decrypt their own data
- [ ] User CANNOT decrypt others' data (403)
- [ ] Audit log records all operations
- [ ] API key rotation works
- [ ] Health endpoint works without auth
- [ ] All integration tests pass
- [ ] Load testing shows <5% performance degradation

---

## Rollback Plan

If issues arise:

1. **Quick rollback**: Disable authentication temporarily
   ```java
   @Configuration
   public class SecurityConfig {
       @Bean
       public SecurityFilterChain filterChain(HttpSecurity http) {
           http.authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
           return http.build();
       }
   }
   ```

2. **Database rollback**: Flyway supports undo migrations
   ```bash
   ./mvnw flyway:undo
   ```

3. **Infrastructure rollback**: Terraform destroy
   ```bash
   cd terraform
   terraform destroy -target=aws_cognito_user_pool.encryption_api
   ```

---

## Next Steps

1. **Review this plan** - Confirm approach
2. **Create Java entities** - User, AuditLog, ApiKey
3. **Implement JWT filter** - Authentication logic
4. **Update services** - Add authorization checks
5. **Test thoroughly** - Unit + integration tests
6. **Deploy** - Terraform + Lambda
7. **Document** - User guide + API docs

---

## Questions?

- Need clarification on any component?
- Want to adjust the security model?
- Concerned about performance?
- Need help with testing strategy?

**Status**: Ready to proceed with Java implementation!
