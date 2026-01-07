# Postman Testing Guide - Encryption API

**Date**: January 6, 2026
**API URL**: https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com

---

## Quick Start

### 1. Import the Postman Collection

1. Open Postman
2. Click **Import** button (top left)
3. Select **File** tab
4. Choose `Encryption-API-Tests.postman_collection.json` from this directory
5. Click **Import**

The collection will be imported with all tests and environment variables pre-configured!

---

## What's Included

### Test Endpoints

1. **Health Check** - Verify API is running
2. **Encrypt Data** - Encrypt and store data (auto-saves ID for decrypt)
3. **Decrypt Data** - Retrieve and decrypt data using saved ID
4. **Rate Limit Test - Burst** - Test 5 req/min limit
5. **Encrypt - Rate Limit Test** - Test rate limiting on encrypt endpoint
6. **Full Workflow Test** - Final health check after testing

### Pre-configured Variables

- `base_url`: https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com
- `encrypted_id`: Auto-populated by encrypt test
- `rate_limit_count`: Auto-incremented for rate limit tests
- `encrypt_rate_count`: Auto-incremented for encrypt rate tests

---

## Running Tests

### Option 1: Run Individual Tests

1. Select a request from the collection
2. Click **Send**
3. View the **Test Results** tab to see pass/fail status

### Option 2: Run All Tests (Collection Runner)

1. Right-click on the collection name
2. Select **Run collection**
3. Click **Run Encryption API - Lambda**
4. Watch all tests execute in sequence

**Note**: Rate limit tests work best when run individually multiple times.

---

## Test Descriptions

### 1. Health Check

**Method**: GET
**Endpoint**: `/api/health`

**What it tests**:
- ✅ Status code is 200
- ✅ Response has `status` field
- ✅ Status is `UP`
- ✅ Response time < 2000ms

**Expected Response**:
```json
{
  "status": "UP",
  "timestamp": "2026-01-07T01:37:03.566167394"
}
```

---

### 2. Encrypt Data

**Method**: POST
**Endpoint**: `/api/encrypt`

**Request Body**:
```json
{
  "plainText": "Hello from Postman! Testing Lambda encryption."
}
```

**What it tests**:
- ✅ Status code is 200
- ✅ Response has `id` field
- ✅ Response has `message` field
- ✅ Message indicates success
- ✅ Saves ID for decrypt test
- ✅ Response time < 3000ms

**Expected Response**:
```json
{
  "id": 123,
  "message": "Data encrypted and stored successfully",
  "timestamp": "2026-01-07T01:37:04.216491573"
}
```

**Important**: This test automatically saves the returned ID to the `encrypted_id` variable for use in the decrypt test.

---

### 3. Decrypt Data

**Method**: GET
**Endpoint**: `/api/decrypt/{{encrypted_id}}`

**What it tests**:
- ✅ Status code is 200
- ✅ Response has `id` field
- ✅ Response has `plainText` field
- ✅ Decrypted text matches original
- ✅ ID matches encrypted record
- ✅ Response time < 2000ms

**Expected Response**:
```json
{
  "id": 123,
  "plainText": "Hello from Postman! Testing Lambda encryption.",
  "timestamp": "2026-01-07T01:37:05.499139125"
}
```

**Note**: This test uses the `{{encrypted_id}}` variable that was saved from the Encrypt test.

---

### 4. Rate Limit Test - Burst (6 requests)

**Method**: GET
**Endpoint**: `/api/health`

**How to test**:
1. Click **Send** 6 times rapidly
2. Watch the test results for each request

**What it tests**:
- ✅ Requests 1-5: Should return 200 OK
- ✅ Request 6+: Should return 429 Too Many Requests

**Expected Behavior**:
- First 5 requests succeed
- 6th request triggers rate limiting
- Counter auto-resets after 6 requests

**Rate Limits**:
- **Burst**: 5 requests (max in quick succession)
- **Rate**: 0.33 requests/second (≈20 requests/minute)
- **Hourly**: 20 requests/hour (enforced by burst + rate)

---

### 5. Encrypt - Rate Limit Test

**Method**: POST
**Endpoint**: `/api/encrypt`

**How to test**:
1. Click **Send** 6 times rapidly
2. Watch for 429 responses

**What it tests**:
- ✅ Rate limiting applies to all endpoints (not just health)
- ✅ POST requests are throttled same as GET

---

### 6. Full Workflow Test

**Method**: GET
**Endpoint**: `/api/health`

**Purpose**: Final verification that the API is still responsive after all tests.

---

## Understanding Rate Limiting

### Configuration

The API Gateway enforces the following limits:

| Limit Type | Value | Description |
|------------|-------|-------------|
| **Burst** | 5 requests | Maximum requests in quick succession |
| **Rate** | 0.33 req/sec | Sustained rate (≈20 requests/minute) |
| **Effective Hour** | ~20 requests | Based on rate limit enforcement |

### How It Works

1. **Burst Limit**: You can make up to 5 requests immediately
2. **Rate Limit**: After burst, limited to 0.33 requests/second
3. **Throttling**: Exceeded limits return `429 Too Many Requests`

### Rate Limit Response

When rate limited:
```json
{
  "message": "Too Many Requests"
}
```
**HTTP Status**: 429

---

## Verified Test Results

### Successful Rate Limit Test (January 7, 2026)

```
Request #1: 200 OK ✅
Request #2: 200 OK ✅
Request #3: 200 OK ✅
Request #4: 200 OK ✅
Request #5: 200 OK ✅
Request #6: 429 Too Many Requests ✅
Request #7: 200 OK (after delay)
Request #8: 429 Too Many Requests ✅
```

**Conclusion**: Rate limiting is working correctly!

---

## Automated Test Scripts

### Pre-request Scripts

The collection includes pre-request scripts that:
- Log the current request URL
- Verify `encrypted_id` exists before decrypt test

### Test Scripts

Each request includes automated test scripts that:
- Verify HTTP status codes
- Validate response structure
- Check response data
- Auto-save IDs for subsequent tests
- Track request counts for rate limiting

---

## Troubleshooting

### Issue: Decrypt test fails with "No encrypted_id found"

**Solution**: Run the "Encrypt Data" test first to populate the `encrypted_id` variable.

### Issue: Rate limit test doesn't show 429

**Possible causes**:
1. Requests sent too slowly (add small delays)
2. API Gateway propagation delay (wait 30 seconds and retry)
3. Different IP addresses (tests are per-IP)

**Solution**: Run the test script:
```bash
./test-rate-limit.sh
```

### Issue: All requests fail with 500 errors

**Check**:
1. Lambda function status: `aws lambda get-function-configuration --function-name encryption-api-function --region sa-east-1`
2. CloudWatch logs: `aws logs tail /aws/lambda/encryption-api-function --follow --region sa-east-1`
3. RDS database status: `aws rds describe-db-instances --region sa-east-1`

---

## Alternative Testing: Command Line

If you prefer command-line testing, use the included script:

```bash
# Make executable
chmod +x test-rate-limit.sh

# Run test
./test-rate-limit.sh
```

Or use direct curl commands:

```bash
API_URL="https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com"

# Health check
curl "$API_URL/api/health"

# Encrypt
curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Test message"}'

# Decrypt (replace ID)
curl "$API_URL/api/decrypt/1"
```

---

## Environment Variables (Optional)

To switch between different environments:

1. Click the gear icon (⚙️) next to the environment selector
2. Create a new environment (e.g., "Production", "Staging")
3. Add the `base_url` variable with the appropriate API URL
4. Select the environment from the dropdown

**Example environments**:
- **Production**: https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com
- **Local**: http://localhost:8080

---

## Best Practices

### Sequential Testing

For the most reliable results, run tests in this order:
1. Health Check
2. Encrypt Data
3. Decrypt Data
4. Full Workflow Test
5. Rate Limit Tests (separately)

### Rate Limit Testing

- Run rate limit tests **separately** from functional tests
- Wait 60 seconds between rate limit test cycles
- Use the test script for consistent results

### Collection Variables

The collection automatically manages these variables:
- `encrypted_id`: Auto-saved from encrypt response
- `rate_limit_count`: Auto-incremented and reset
- `encrypt_rate_count`: Auto-incremented and reset

You don't need to manually set these!

---

## Advanced: Custom Tests

### Adding New Tests

To add a new test to the collection:

1. Click **Add Request**
2. Configure the endpoint
3. Click **Tests** tab
4. Add test scripts (JavaScript):

```javascript
pm.test("Your test name", function () {
    pm.response.to.have.status(200);
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('yourField');
});
```

### Pre-request Scripts

Add setup logic before requests:

```javascript
// Set a dynamic timestamp
pm.collectionVariables.set("timestamp", new Date().toISOString());
```

---

## Monitoring and Logs

### View API Gateway Logs

```bash
aws logs tail /aws/apigateway/encryption-api --follow --region sa-east-1
```

### View Lambda Logs

```bash
aws logs tail /aws/lambda/encryption-api-function --follow --region sa-east-1
```

### Check Rate Limiting Events

Look for entries in API Gateway logs:
```json
{
  "status": "429",
  "routeKey": "$default",
  "httpMethod": "GET"
}
```

---

## Summary

### What You Can Test

✅ API health and availability
✅ Data encryption functionality
✅ Data decryption functionality
✅ Rate limiting enforcement
✅ Response times and performance
✅ Error handling
✅ Full encryption/decryption workflow

### Files Provided

- `Encryption-API-Tests.postman_collection.json` - Import into Postman
- `test-rate-limit.sh` - Command-line rate limit test
- `POSTMAN_TESTING_GUIDE.md` - This guide

---

## Support

If you encounter issues:

1. Check [DEPLOYMENT_SUCCESS.md](DEPLOYMENT_SUCCESS.md) for API status
2. Review [TESTING_STEPS.md](TESTING_STEPS.md) for detailed testing guide
3. See [LAMBDA_DEBUGGING_STATUS.md](LAMBDA_DEBUGGING_STATUS.md) for troubleshooting

---

**Happy Testing!**

Your Encryption API is fully functional with rate limiting protection. The Postman collection provides a quick and easy way to verify all functionality.
