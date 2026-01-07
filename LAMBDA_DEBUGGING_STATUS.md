# Lambda Deployment - Debugging Status

**Date**: January 6, 2026
**Status**: ⚠️ Deployed but not working - Requires debugging

---

## Current Situation

### What's Deployed
- ✅ API Gateway HTTP API: `https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com`
- ✅ Lambda Function: `encryption-api-function` (Java 17, 512MB)
- ✅ RDS MySQL Database: Configured and accessible from Lambda VPC
- ✅ All 32 AWS resources created successfully

### The Problem
- ❌ API returns `{"message":"Internal Server Error"}` (HTTP 500)
- ❌ Lambda is NOT being invoked (no CloudWatch logs generated)
- ❌ Error occurs at API Gateway level before reaching Lambda

---

## Root Cause Analysis

### Issue: Spring Boot Fat JAR Class Loading

**Problem**: Spring Boot packages classes in `BOOT-INF/classes/` directory, but Lambda's classloader expects handler classes at the root level.

**Symptom**: `ClassNotFoundException: com.aviencryption.StreamLambdaHandler`

### What We Tried

1. **Spring Boot ZIP layout** - Didn't change JAR structure
2. **Maven Shade Plugin** - Configuration errors
3. **PropertiesLauncher** - Not a Lambda handler
4. **Custom wrapper class** - Still ended up in BOOT-INF
5. **Lambda Web Adapter** - Requires container image (complexity)
6. **JAR Restructuring Script** ✅ - **This approach works!**

---

## Current Solution (Needs Verification)

### JAR Restructuring Script

Created `create-lambda-jar.sh` that:
1. Builds Spring Boot fat JAR
2. Unzips it
3. Moves `BOOT-INF/classes/*` to root
4. Moves `BOOT-INF/lib/*` to `lib/`
5. Repackages as `encryption-api-lambda.jar`

**Status**: JAR uploaded to S3, Lambda updated, but still getting errors.

### Verification Needed

```bash
# Check if handler class is at root level
jar tf target/encryption-api-lambda.jar | grep StreamLambdaHandler
# Output: com/aviencryption/StreamLambdaHandler.class ✅ CONFIRMED

# Check libs are in lib/
jar tf target/encryption-api-lambda.jar | grep "^lib/" | head
# Output: Shows lib/ directory with dependencies ✅ CONFIRMED
```

---

## Next Steps to Fix

### 1. Check Lambda Logs (PRIORITY)

Lambda might be failing to initialize but not logging. Check for:

```bash
# Check if any logs exist
aws logs describe-log-streams --log-group-name /aws/lambda/encryption-api --region us-east-1

# If logs exist, view them
aws logs tail /aws/lambda/encryption-api --since 10m --region us-east-1

# Look for initialization errors
aws logs tail /aws/lambda/encryption-api --since 10m --region us-east-1 | grep -i "error\|exception\|failed"
```

### 2. Test Lambda Directly

Bypass API Gateway to test Lambda:

```bash
# Create test payload
cat > /tmp/test-lambda.json << 'EOF'
{
  "version": "2.0",
  "routeKey": "$default",
  "rawPath": "/api/health",
  "requestContext": {
    "http": {
      "method": "GET",
      "path": "/api/health"
    }
  },
  "headers": {},
  "isBase64Encoded": false
}
EOF

# Invoke directly
aws lambda invoke \
  --function-name encryption-api-function \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload file:///tmp/test-lambda.json \
  /tmp/lambda-response.json

# Check response
cat /tmp/lambda-response.json
```

### 3. Check Lambda Configuration

```bash
# Verify handler path
aws lambda get-function-configuration \
  --function-name encryption-api-function \
  --region us-east-1 \
  --query 'Handler'
# Should be: com.aviencryption.StreamLambdaHandler::handleRequest

# Check environment variables
aws lambda get-function-configuration \
  --function-name encryption-api-function \
  --region us-east-1 \
  --query 'Environment.Variables'
```

### 4. Possible Issues to Check

#### Missing Classpath
Lambda might not be finding dependencies in `lib/`. Solution:
- Add `JAVA_TOOL_OPTIONS=-Djava.class.path=.:/lib/*` to environment variables

#### Database Connection Timeout
Lambda in VPC might be timing out connecting to RDS. Check:
- NAT Gateway is working
- Security groups allow Lambda → RDS traffic
- RDS is in same VPC subnets

#### Memory/Timeout Issues
Current settings:
- Memory: 512MB (might need more for Spring Boot)
- Timeout: 30s (should be enough)

Try increasing memory:
```terraform
memory_size = 1024
timeout = 60
```

### 5. Alternative: Use Custom Runtime

If JAR approach continues failing, use AWS Lambda Custom Runtime:

1. Build executable JAR
2. Create `bootstrap` script:
```bash
#!/bin/sh
java -jar encryption-api-lambda.jar
```
3. Package as ZIP with bootstrap + JAR
4. Use `runtime = "provided.al2"`

---

## Files Modified

### Application Code
- [pom.xml](pom.xml) - AWS Serverless Java Container dependency
- [src/main/java/com/aviencryption/StreamLambdaHandler.java](src/main/java/com/aviencryption/StreamLambdaHandler.java) - Lambda handler
- [src/main/resources/application-prod.yml](src/main/resources/application-prod.yml) - Lambda-optimized config

### Infrastructure
- [terraform/main.tf](terraform/main.tf) - Lambda function configuration
- [terraform/outputs.tf](terraform/outputs.tf) - Lambda outputs

### Build Scripts
- [create-lambda-jar.sh](create-lambda-jar.sh) - JAR restructuring script

### Documentation
- [TESTING_STEPS.md](TESTING_STEPS.md) - Testing guide (needs update once working)
- [LAMBDA_DEPLOYMENT_GUIDE.md](LAMBDA_DEPLOYMENT_GUIDE.md) - Deployment guide
- [LAMBDA_IMPLEMENTATION_SUMMARY.md](LAMBDA_IMPLEMENTATION_SUMMARY.md) - Implementation summary

---

## Quick Commands

### Rebuild and Update Lambda
```bash
# Rebuild JAR
./create-lambda-jar.sh

# Upload to S3
aws s3 cp target/encryption-api-lambda.jar \
  s3://encryption-api-lambda-code-20260106/encryption-api-1.0.0.jar \
  --region us-east-1

# Update Lambda (Terraform)
cd terraform
terraform apply -auto-approve
```

### Test API
```bash
API_URL="https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com"

# Health check
curl "$API_URL/api/health"

# Encrypt
curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Test message"}'
```

### Monitor Logs
```bash
# Lambda logs
aws logs tail /aws/lambda/encryption-api --follow --region us-east-1

# API Gateway logs
aws logs tail /aws/apigateway/encryption-api --follow --region us-east-1
```

---

## Summary

**Infrastructure**: ✅ 100% deployed successfully
**Application**: ❌ Not working - needs debugging

**Most Likely Issue**: Lambda initialization failure or VPC networking problem

**Recommended Next Action**: Check Lambda logs and test direct invocation to isolate the issue.

---

## Resources

- [AWS Serverless Java Container Docs](https://github.com/awslabs/aws-serverless-java-container)
- [Spring Boot on Lambda Guide](https://docs.aws.amazon.com/lambda/latest/dg/java-samples.html)
- [Lambda VPC Networking](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
