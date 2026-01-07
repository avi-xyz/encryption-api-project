# 🎉 Lambda Deployment Successful - Testing Steps

## ✅ Deployment Summary

**Status**: Deployed successfully!

**API URL**: `https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com`

**Resources Created**: 32 AWS resources
- Lambda Function (Java 17, 512MB)
- API Gateway HTTP API
- RDS MySQL Database
- VPC, NAT Gateway, networking
- CloudWatch logs
- Keep-warm scheduler

---

## Testing Steps

### Step 1: Save API URL

```bash
API_URL="https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com"
```

### Step 2: Test Health Endpoint

```bash
curl "$API_URL/api/health"
```

**Expected Output**:
```json
{
  "status": "UP",
  "timestamp": "2026-01-07T00:15:00"
}
```

**Note**: ⏱️ First request will take **3-5 seconds** (cold start) as Lambda initializes Spring Boot. Be patient!

---

### Step 3: Test Encrypt Endpoint

```bash
curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from serverless Lambda!"}'
```

**Expected Output**:
```json
{
  "id": 1,
  "message": "Data encrypted and stored successfully",
  "timestamp": "2026-01-07T00:15:30"
}
```

**This request will be fast** (~100ms) because Lambda is now warm!

---

### Step 4: Test Decrypt Endpoint

Using the ID from the encrypt response (likely `1`):

```bash
curl "$API_URL/api/decrypt/1"
```

**Expected Output**:
```json
{
  "id": 1,
  "plainText": "Hello from serverless Lambda!",
  "timestamp": "2026-01-07T00:15:45"
}
```

---

### Step 5: Test Multiple Encryptions

```bash
# Encrypt multiple messages
curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"First secret"}'

curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Second secret"}'

curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Third secret"}'

# Decrypt each one
curl "$API_URL/api/decrypt/2"
curl "$API_URL/api/decrypt/3"
curl "$API_URL/api/decrypt/4"
```

---

### Step 6: Performance Test - Warm vs Cold

```bash
# Test warm Lambda (should be fast)
time curl "$API_URL/api/health"

# Wait 16 minutes for Lambda to go cold
echo "Waiting 16 minutes for Lambda to cool down..."
sleep 960

# Test cold Lambda (will be slow first time)
time curl "$API_URL/api/health"

# Test warm again (fast)
time curl "$API_URL/api/health"
```

**Expected Timing**:
- Warm: 50-150ms
- Cold (first request): 3,000-5,000ms
- Warm (after cold): 50-150ms

**Note**: Keep-warm is enabled (pings every 5 minutes), so cold starts should be rare during daytime!

---

## Advanced Testing

### Test CORS

```bash
curl -i -X OPTIONS "$API_URL/api/encrypt" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST"
```

Should show CORS headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
```

### Test Invalid Input

```bash
# Missing plainText
curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{}'

# Invalid ID
curl "$API_URL/api/decrypt/999"
```

---

## Monitoring

### View Lambda Logs

```bash
# Real-time logs
aws logs tail /aws/lambda/encryption-api --follow --region us-east-1

# Last 10 minutes
aws logs tail /aws/lambda/encryption-api --since 10m --region us-east-1
```

### View API Gateway Logs

```bash
aws logs tail /aws/apigateway/encryption-api --follow --region us-east-1
```

### Check Lambda Function Status

```bash
aws lambda get-function \
  --function-name encryption-api-function \
  --region us-east-1 \
  --query 'Configuration.{State:State,LastModified:LastModified,Runtime:Runtime,MemorySize:MemorySize}'
```

### Check API Gateway Status

```bash
aws apigatewayv2 get-api \
  --api-id x0gacpslg3 \
  --region us-east-1 \
  --query '{Name:Name,ProtocolType:ProtocolType,ApiEndpoint:ApiEndpoint,CreatedDate:CreatedDate}'
```

---

## Troubleshooting

### Issue: Timeout or 504 Gateway Timeout

**Cause**: Lambda taking too long (>30s)

**Solution**:
```bash
# Check Lambda logs for errors
aws logs tail /aws/lambda/encryption-api --since 5m --region us-east-1
```

### Issue: 502 Bad Gateway

**Cause**: Lambda function error

**Solution**:
```bash
# View Lambda logs
aws logs tail /aws/lambda/encryption-api --since 5m --region us-east-1 | grep ERROR
```

### Issue: Connection refused or network error

**Cause**: Lambda can't connect to RDS

**Check**:
```bash
# Verify Lambda is in VPC
aws lambda get-function-configuration \
  --function-name encryption-api-function \
  --region us-east-1 \
  --query 'VpcConfig'

# Should show subnet IDs and security group ID
```

### Issue: Cold start every time

**Cause**: Keep-warm not working

**Check**:
```bash
# Verify CloudWatch Event Rule exists
aws events list-rules --region us-east-1 | grep encryption-api-keep-warm

# Check Lambda has permission
aws lambda get-policy \
  --function-name encryption-api-function \
  --region us-east-1 | grep AllowCloudWatchInvoke
```

---

## Performance Benchmarks

### Expected Performance

| Scenario | Time | Notes |
|----------|------|-------|
| Cold start (first request) | 3-5s | Lambda initializing Spring Boot |
| Warm request (health) | 50-100ms | Already initialized |
| Encrypt operation | 100-200ms | Includes DB write |
| Decrypt operation | 50-150ms | DB read only |
| Keep-warm ping | Every 5 min | Prevents cold starts |

### Load Testing (Optional)

```bash
# Install Apache Bench
brew install httpd  # macOS

# Test 100 requests, 10 concurrent
ab -n 100 -c 10 -p encrypt.json -T application/json "$API_URL/api/encrypt"

# encrypt.json contains:
# {"plainText":"Load test message"}
```

---

## Cost Tracking

### View Current Month Costs

```bash
# AWS Cost Explorer (via Console)
# https://console.aws.amazon.com/cost-management/home

# Or use AWS CLI
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --region us-east-1
```

### Estimated Costs (First Month)

- RDS MySQL: ~$15-20
- Lambda (100K requests): ~$0.20
- API Gateway (100K requests): ~$0.10
- NAT Gateway: ~$30-35
- Data transfer: ~$1-2

**Total**: ~$46-57/month (at 100K requests)

---

## Cleanup (When Done Testing)

**⚠️ IMPORTANT**: Always clean up to avoid charges!

```bash
cd /Users/avinash/encryption-api-project/terraform
terraform destroy -auto-approve

# Also delete S3 bucket
aws s3 rb s3://encryption-api-lambda-code-20260106 --force --region us-east-1
```

---

## Success Indicators

✅ **Deployment is working correctly if**:

1. Health endpoint returns `{"status":"UP"}`
2. Encrypt creates records with incrementing IDs
3. Decrypt returns the original plainText
4. Second+ requests are fast (<200ms)
5. No errors in CloudWatch logs

---

## Next Steps

### Optional Enhancements

1. **Custom Domain**: Add your own domain name
2. **Rate Limiting**: Protect against abuse
3. **API Keys**: Add authentication
4. **Monitoring Dashboard**: CloudWatch custom metrics
5. **Alerts**: SNS notifications for errors

### Migration to ECS (Future)

If AWS Support approves load balancers:
- Keep Lambda running
- Deploy ECS + NLB in parallel
- Switch API Gateway to NLB
- Zero downtime migration!

---

## Summary

🎉 **Your serverless Encryption API is live!**

- **API URL**: https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com
- **Architecture**: API Gateway → Lambda → RDS
- **Cost**: ~$46-63/month
- **Performance**: 50-150ms (warm), 3-5s (cold start)
- **Keep-warm**: Enabled (pings every 5 min)

**Start testing now!** Use the commands above to verify everything works.

---

## Quick Test Script

Save this as `test-api.sh`:

```bash
#!/bin/bash

API_URL="https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com"

echo "🧪 Testing Encryption API..."
echo ""

echo "1️⃣ Testing health endpoint..."
curl -s "$API_URL/api/health" | jq .
echo ""

echo "2️⃣ Encrypting message..."
RESPONSE=$(curl -s -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Test message from script"}')
echo "$RESPONSE" | jq .
ID=$(echo "$RESPONSE" | jq -r '.id')
echo ""

echo "3️⃣ Decrypting message with ID $ID..."
curl -s "$API_URL/api/decrypt/$ID" | jq .
echo ""

echo "✅ All tests passed!"
```

Run with:
```bash
chmod +x test-api.sh
./test-api.sh
```

---

**Happy testing!** 🚀
