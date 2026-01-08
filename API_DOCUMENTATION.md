# Encryption API Documentation

**Base URL**: `https://3tyukwdl69.execute-api.us-east-1.amazonaws.com`

## Requesting API Access

### How to Get Access

To use this API, you must first request access credentials via GitHub:

1. **[Submit an Access Request Issue](https://github.com/avi-xyz/encryption-api/issues/new?template=api-access-request.yml)**
2. Fill out the required information:
   - Email address (this becomes your username)
   - Full name and organization
   - Use case description
   - Expected usage volume
3. **Wait for approval** (typically 24-48 hours)
4. **Receive your credentials** via email or GitHub issue comment

Once approved, you'll receive:
- **Username**: Your email address
- **Temporary Password**: You'll change this on first login
- **Access to the API**: Use the authentication endpoints below

---

## Authentication

All API endpoints (except `/api/health` and `/api/auth/**`) require JWT authentication via AWS Cognito.

### Getting Your Credentials

To use this API, you need a username and password. Contact your administrator to:

1. **Create your account** in the Cognito user pool
2. **Receive your temporary password** via email (or through administrator)
3. **Set your permanent password** on first login

**Administrator Setup Process:**
```bash
# Create a new user
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_D0eoSAzr8 \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_D0eoSAzr8 \
  --username user@example.com \
  --password "YourSecurePassword123!" \
  --permanent
```

**Password Requirements:**
- Minimum 12 characters
- Must contain: uppercase, lowercase, numbers, and symbols
- Example: `MySecure@Pass123!`

### Option 1: HTTP API Login (Recommended)

Use the built-in login endpoint to obtain JWT tokens without AWS CLI.

**Endpoint**: `POST /api/auth/login`
**Authentication**: Not required
**Content-Type**: `application/json`

**Request Body**:
```json
{
  "username": "your-email@example.com",
  "password": "your-password"
}
```

**Example Request**:
```bash
curl -X POST https://3tyukwdl69.execute-api.us-east-1.amazonaws.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"your-email@example.com","password":"your-password"}'
```

**Response**:
```json
{
  "idToken": "eyJraWQiOiJ...",
  "accessToken": "eyJraWQiOiJ...",
  "refreshToken": "eyJjdHkiOiJ...",
  "expiresIn": 3600,
  "tokenType": "Bearer"
}
```

**Token Validity**: 60 minutes
**Note**: Use the `idToken` in the `Authorization: Bearer` header for all API requests.

### Option 2: AWS CLI (Alternative)

For users with AWS CLI configured:

```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id 4fks3earpocs8e9f03l5tj4n1g \
  --auth-parameters USERNAME=your-email@example.com,PASSWORD=your-password \
  --query 'AuthenticationResult.IdToken' \
  --output text
```

### Refresh Token

Refresh your access token without re-entering credentials.

**Endpoint**: `POST /api/auth/refresh`
**Authentication**: Not required
**Content-Type**: `application/json`

**Request Body**:
```json
{
  "refreshToken": "eyJjdHkiOiJ..."
}
```

**Example Request**:
```bash
curl -X POST https://3tyukwdl69.execute-api.us-east-1.amazonaws.com/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"YOUR_REFRESH_TOKEN"}'
```

**Response**:
```json
{
  "idToken": "eyJraWQiOiJ...",
  "accessToken": "eyJraWQiOiJ...",
  "expiresIn": 3600,
  "tokenType": "Bearer"
}
```

**Note**: Refresh tokens are valid for 30 days.

---

## Endpoints

### 1. Health Check

Check API availability.

**Endpoint**: `GET /api/health`
**Authentication**: Not required

**Example Request**:
```bash
curl https://3tyukwdl69.execute-api.us-east-1.amazonaws.com/api/health
```

**Response**:
```json
{
  "status": "UP",
  "timestamp": "2026-01-08T10:30:00.123456789"
}
```

---

### 2. Encrypt Data

Encrypt and store sensitive data.

**Endpoint**: `POST /api/encrypt`
**Authentication**: Required (JWT Bearer token)
**Content-Type**: `application/json`

**Request Body**:
```json
{
  "plainText": "Your sensitive data here"
}
```

**Example Request**:
```bash
curl -X POST https://3tyukwdl69.execute-api.us-east-1.amazonaws.com/api/encrypt \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"My credit card number is 1234-5678-9012-3456"}'
```

**Success Response** (201 Created):
```json
{
  "id": 42,
  "message": "Data encrypted and stored successfully",
  "userId": "26da9b92-6faa-40b7-be18-ec9f0726a2f4",
  "timestamp": "2026-01-08T10:30:00.123456789"
}
```

**Error Responses**:
- `401 Unauthorized`: Missing or invalid JWT token
- `400 Bad Request`: Invalid request body

---

### 3. Decrypt Data

Retrieve and decrypt previously encrypted data.

**Endpoint**: `GET /api/decrypt/{id}`
**Authentication**: Required (JWT Bearer token)

**Path Parameters**:
- `id` (integer): The ID returned from the encrypt endpoint

**Example Request**:
```bash
curl https://3tyukwdl69.execute-api.us-east-1.amazonaws.com/api/decrypt/42 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Success Response** (200 OK):
```json
{
  "id": 42,
  "plainText": "My credit card number is 1234-5678-9012-3456",
  "userId": "26da9b92-6faa-40b7-be18-ec9f0726a2f4",
  "timestamp": "2026-01-08T10:30:15.987654321"
}
```

**Error Responses**:
- `401 Unauthorized`: Missing or invalid JWT token
- `403 Forbidden`: Attempting to access another user's data
- `404 Not Found`: Record with specified ID does not exist

---

## Security Features

### Multi-Tenant Data Isolation
- Each user can only access their own encrypted data
- Data is automatically associated with the authenticated user
- Cross-user access attempts return `403 Forbidden`

### Just-In-Time (JIT) User Provisioning
- First-time API users are automatically created in the database
- User records are created from Cognito JWT claims
- No manual database setup required

### Encryption
- AES-256 encryption with secure master key
- Data encrypted at rest in database
- Encryption keys stored securely in AWS Secrets Manager

### JWT Token Security
- RS256 signature validation against Cognito public keys
- Token expiration: 60 minutes
- Automatic token refresh supported via RefreshToken

---

## Code Examples

### Python Example

```python
import requests

# API Base URL
BASE_URL = 'https://3tyukwdl69.execute-api.us-east-1.amazonaws.com'

# Get JWT token via HTTP API
login_response = requests.post(
    f'{BASE_URL}/api/auth/login',
    json={
        'username': 'your-email@example.com',
        'password': 'your-password'
    }
)
jwt_token = login_response.json()['idToken']

# Encrypt data
headers = {
    'Authorization': f'Bearer {jwt_token}',
    'Content-Type': 'application/json'
}
data = {'plainText': 'My sensitive data'}
encrypt_response = requests.post(
    f'{BASE_URL}/api/encrypt',
    headers=headers,
    json=data
)
encrypted_id = encrypt_response.json()['id']
print(f"Encrypted data ID: {encrypted_id}")

# Decrypt data
decrypt_response = requests.get(
    f'{BASE_URL}/api/decrypt/{encrypted_id}',
    headers=headers
)
print(f"Decrypted data: {decrypt_response.json()['plainText']}")
```

### Node.js Example

```javascript
const axios = require('axios');

const BASE_URL = 'https://3tyukwdl69.execute-api.us-east-1.amazonaws.com';

async function getToken(username, password) {
  const response = await axios.post(`${BASE_URL}/api/auth/login`, {
    username,
    password
  });
  return response.data.idToken;
}

async function encryptData(token, plainText) {
  const response = await axios.post(
    `${BASE_URL}/api/encrypt`,
    { plainText },
    { headers: { 'Authorization': `Bearer ${token}` } }
  );
  return response.data.id;
}

async function decryptData(token, id) {
  const response = await axios.get(
    `${BASE_URL}/api/decrypt/${id}`,
    { headers: { 'Authorization': `Bearer ${token}` } }
  );
  return response.data.plainText;
}

// Usage
(async () => {
  const token = await getToken('your-email@example.com', 'your-password');
  const id = await encryptData(token, 'My sensitive data');
  console.log(`Encrypted data ID: ${id}`);

  const plainText = await decryptData(token, id);
  console.log(`Decrypted data: ${plainText}`);
})();
```

### cURL Example (Shell Script)

```bash
#!/bin/bash

BASE_URL="https://3tyukwdl69.execute-api.us-east-1.amazonaws.com"

# Get JWT token via HTTP API
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"your-email@example.com","password":"your-password"}')

JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.idToken')

# Encrypt data
ENCRYPT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/encrypt" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"My sensitive data"}')

ENCRYPTED_ID=$(echo "$ENCRYPT_RESPONSE" | jq -r '.id')
echo "Encrypted data ID: $ENCRYPTED_ID"

# Decrypt data
DECRYPT_RESPONSE=$(curl -s "$BASE_URL/api/decrypt/$ENCRYPTED_ID" \
  -H "Authorization: Bearer $JWT_TOKEN")

PLAIN_TEXT=$(echo "$DECRYPT_RESPONSE" | jq -r '.plainText')
echo "Decrypted data: $PLAIN_TEXT"
```

---

## Rate Limits

Currently, no rate limits are enforced. Standard AWS API Gateway throttling applies:
- Steady-state: 10,000 requests per second
- Burst: 5,000 requests

---

## Support

For technical support or questions:
- Email: support@yourcompany.com
- Documentation: https://docs.yourcompany.com

---

**Last Updated**: 2026-01-08
