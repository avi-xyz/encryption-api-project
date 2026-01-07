# Lambda Serverless Deployment Guide

## Overview

This guide covers deploying the Encryption API as a **serverless AWS Lambda function** with API Gateway, completely bypassing the load balancer restriction.

**Architecture**: API Gateway (HTTPS) → Lambda Function → RDS MySQL

**Cost**: $46-63/month (cheaper than blocked NLB solution at $67-90/month)

**Status**: ✅ **Ready to deploy immediately!**

---

## Prerequisites

- ✅ AWS CLI configured (`aws configure`)
- ✅ Terraform installed
- ✅ Java 17 and Maven installed
- ✅ Project built successfully

---

## Step 1: Build the Lambda-Compatible JAR

The application has been updated to support Lambda with:
- AWS Serverless Java Container dependency
- Lambda handler class ([StreamLambdaHandler.java](src/main/java/com/aviencryption/StreamLambdaHandler.java))
- Optimized database connection pool settings

**Build command:**

```bash
cd /Users/avinash/encryption-api-project
./mvnw clean package -DskipTests
```

**Verify the build:**

```bash
ls -lh target/encryption-api-1.0.0.jar
# Should show ~59MB JAR file

# Verify Lambda handler is included
jar tf target/encryption-api-1.0.0.jar | grep StreamLambdaHandler
# Should show: BOOT-INF/classes/com/aviencryption/StreamLambdaHandler.class
```

---

## Step 2: Review Terraform Configuration

The Terraform configuration has been updated for Lambda deployment:

**File**: [terraform/main.tf](terraform/main.tf) (Lambda version)
**Backup**: [terraform/main-ecs-nlb-blocked.tf](terraform/main-ecs-nlb-blocked.tf) (ECS version - blocked)

**Key resources**:
- AWS Lambda function (Java 17 runtime, 512MB memory, 30s timeout)
- API Gateway HTTP API with CORS
- VPC and networking (for Lambda → RDS access)
- RDS MySQL database
- CloudWatch logs
- Keep-warm event rule (prevents cold starts)

**Review configuration**:

```bash
cd terraform
cat terraform.tfvars
```

Should show:
```
aws_region  = "sa-east-1"
environment = "development"
db_username = "admin"
db_password = "nVhGfSr0PBteTmEO2jLU"
master_encryption_key = "lE/q+9LAjDtAYwDkTAWk7DOHctb81HWcEqUbAcM5+A4="
```

---

## Step 3: Deploy Infrastructure

### Initialize Terraform

```bash
cd terraform
terraform init
```

### Review the Deployment Plan

```bash
terraform plan
```

Expected resources (~30):
- 1 VPC with subnets, NAT Gateway, route tables
- 2 Security groups (Lambda, RDS)
- 1 RDS MySQL instance
- 1 Lambda function
- 1 API Gateway with integration
- 2 CloudWatch log groups
- 1 CloudWatch Event Rule (keep-warm)
- Secrets Manager secrets
- IAM roles and policies

### Deploy

```bash
terraform apply
```

**Time**: ~8-10 minutes

**Watch for**:
- RDS database creation (~5 minutes)
- Lambda function deployment (~1 minute)
- API Gateway setup (~1 minute)

---

## Step 4: Get API URL

After deployment completes:

```bash
cd terraform
terraform output api_gateway_url
```

Example output:
```
https://abc123xyz.execute-api.sa-east-1.amazonaws.com
```

**Save this URL - this is your API endpoint!**

---

## Step 5: Test the API

### Health Check

```bash
API_URL=$(cd terraform && terraform output -raw api_gateway_url)

curl $API_URL/api/health
```

Expected response:
```json
{
  "status": "UP",
  "timestamp": "2026-01-06T23:00:00"
}
```

**Note**: First request may take 3-5 seconds (cold start). Subsequent requests will be fast (<100ms).

### Encrypt Data

```bash
curl -X POST $API_URL/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from Lambda!"}'
```

Expected response:
```json
{
  "id": 1,
  "message": "Data encrypted and stored successfully",
  "timestamp": "2026-01-06T23:00:00"
}
```

### Decrypt Data

```bash
curl $API_URL/api/decrypt/1
```

Expected response:
```json
{
  "id": 1,
  "plainText": "Hello from Lambda!",
  "timestamp": "2026-01-06T23:00:00"
}
```

---

## Step 6: Monitor and Troubleshoot

### View Lambda Logs

```bash
# Tail live logs
aws logs tail /aws/lambda/encryption-api --follow --region sa-east-1

# View recent logs
aws logs tail /aws/lambda/encryption-api --since 10m --region sa-east-1
```

### View API Gateway Logs

```bash
aws logs tail /aws/apigateway/encryption-api --follow --region sa-east-1
```

### Check Lambda Function

```bash
aws lambda get-function \
  --function-name encryption-api-function \
  --region sa-east-1
```

### Invoke Lambda Directly (Bypass API Gateway)

```bash
aws lambda invoke \
  --function-name encryption-api-function \
  --region sa-east-1 \
  --payload '{"httpMethod":"GET","path":"/api/health"}' \
  response.json

cat response.json
```

---

## Performance Characteristics

### Cold Start
- **First request after idle**: 3-5 seconds
- **Frequency**: Only when function hasn't been called recently

### Warm Start
- **Subsequent requests**: 50-100ms
- **Duration**: Function stays warm for ~15 minutes after last request

### Keep-Warm Optimization
- **CloudWatch Event pings every 5 minutes**
- **Effect**: Eliminates cold starts during active hours
- **Cost**: Free (within Lambda free tier)

To disable keep-warm (saves minimal costs):
```bash
cd terraform
# Comment out the keep-warm resources in main.tf
terraform apply
```

---

## Updating the Lambda Function

After making code changes:

### 1. Rebuild JAR

```bash
cd /Users/avinash/encryption-api-project
./mvnw clean package -DskipTests
```

### 2. Update Lambda

```bash
cd terraform
terraform apply
```

Terraform will detect the JAR file change and update the Lambda function automatically.

**OR** update directly with AWS CLI:

```bash
aws lambda update-function-code \
  --function-name encryption-api-function \
  --zip-file fileb://../target/encryption-api-1.0.0.jar \
  --region sa-east-1
```

---

## Cost Management

### Monthly Costs

**Low traffic** (100K requests/month): **~$46-57**
- RDS MySQL: $15-20
- Lambda execution: $0.20
- Lambda requests: $0.02
- NAT Gateway: $30-35
- API Gateway: $0.10
- Data transfer: $1-2

**Medium traffic** (1M requests/month): **~$50-63**
- RDS MySQL: $15-20
- Lambda execution: $2.00
- Lambda requests: $0.20
- NAT Gateway: $30-35
- API Gateway: $1.00
- Data transfer: $2-5

### AWS Free Tier (First 12 Months)

- **Lambda**: 1M requests/month FREE
- **Lambda compute**: 400,000 GB-seconds/month FREE
- **API Gateway**: 1M requests/month FREE (HTTP APIs)

**Result**: At low traffic, you can run the entire API FREE for the first year (only pay RDS + NAT Gateway = ~$45-55/month)

### Always Clean Up When Done

```bash
cd terraform
terraform destroy
```

---

## Architecture Diagram

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────┐
│  API Gateway        │  ← Public HTTPS endpoint
│  (HTTP API)         │  ← SSL/TLS termination
│  + CORS enabled     │  ← Request/response logging
└──────┬──────────────┘
       │ AWS_PROXY integration
       ▼
┌─────────────────────┐
│  Lambda Function    │  ← Serverless compute
│  (Java 17)          │  ← 512MB memory, 30s timeout
│  Spring Boot 3.2    │  ← Full application in Lambda
│  + Handler          │  ← StreamLambdaHandler
└──────┬──────────────┘
       │ VPC access (private subnet)
       ▼
┌─────────────────────┐
│  RDS MySQL 8        │  ← Database
│  (db.t3.micro)      │  ← Private subnet
│  + Encrypted        │  ← 20GB-100GB storage
└─────────────────────┘
```

---

## Comparison: Lambda vs ECS+NLB (Blocked)

| Feature | Lambda (Current) | ECS + NLB (Blocked) |
|---------|------------------|---------------------|
| **Can Deploy** | ✅ YES | ❌ NO (load balancer restricted) |
| **Cost/Month** | $46-63 | $67-90 |
| **HTTPS** | ✅ Built-in | ✅ API Gateway |
| **Auto-Scaling** | ✅ Automatic (0-1000s) | ⚠️ Manual (1-5 tasks) |
| **Cold Start** | ⚠️ 3-5s (first request) | ✅ None |
| **Warm Performance** | ✅ 50-100ms | ✅ 50-100ms |
| **Maintenance** | ✅ Minimal | ⚠️ Container management |
| **Complexity** | ✅ Simple | ⚠️ More complex |

**Winner**: Lambda (can deploy now, cheaper, simpler)

---

## Troubleshooting

### Issue: Lambda timeout error

**Cause**: Database connection taking too long

**Solution**:
```bash
# Increase Lambda timeout
cd terraform
# Edit main.tf: Change timeout = 30 to timeout = 60
terraform apply
```

### Issue: Cold start too slow

**Solutions**:
1. **Enable provisioned concurrency** (costs +$6-10/month):
```terraform
resource "aws_lambda_provisioned_concurrency_config" "api" {
  function_name = aws_lambda_function.api.function_name
  provisioned_concurrent_executions = 1
  qualifier = aws_lambda_alias.live.name
}
```

2. **Keep-warm is already enabled** - pings every 5 minutes

3. **Reduce memory** (faster cold starts but slower execution):
```terraform
memory_size = 256  # Down from 512
```

### Issue: Database connection errors

**Check**:
1. Lambda is in the correct VPC subnets
2. Security group allows Lambda → RDS traffic
3. RDS endpoint is correct
4. Database credentials are correct

**Debug**:
```bash
# Check Lambda environment variables
aws lambda get-function-configuration \
  --function-name encryption-api-function \
  --region sa-east-1 \
  --query 'Environment'
```

### Issue: "No space left on device"

**Cause**: Lambda `/tmp` directory full (512MB limit)

**Solution**: This app doesn't use `/tmp` - if you see this, check for logs or temp files

---

## Next Steps

### ✅ Deployed and Working

Congratulations! Your API is now running serverlessly on AWS Lambda.

### Optional Enhancements

1. **Custom Domain**:
```terraform
resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.yourdomain.com"
  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}
```

2. **Rate Limiting**:
```terraform
resource "aws_apigatewayv2_route" "encrypt" {
  # Add throttle settings
  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }
}
```

3. **API Keys/Authentication**:
- Add Lambda authorizer
- Use Cognito User Pools
- Implement JWT validation

4. **Monitoring Dashboard**:
- Set up CloudWatch Dashboard
- Configure alarms for errors
- Track request metrics

5. **CI/CD Pipeline**:
- GitHub Actions to build JAR
- Automatically update Lambda on push
- Run tests before deployment

---

## Migration Path (If AWS Support Approves Load Balancers)

If AWS Support later approves load balancer access and you want to migrate to ECS:

1. **Keep Lambda running**
2. **Deploy ECS + NLB** using `main-ecs-nlb-blocked.tf`
3. **Test ECS deployment**
4. **Switch API Gateway integration** from Lambda to NLB
5. **Remove Lambda** after verification

**Zero downtime migration possible!**

---

## Support

**Documentation**:
- [SERVERLESS_LAMBDA_OPTION.md](SERVERLESS_LAMBDA_OPTION.md) - Full technical analysis
- [CRITICAL_DEPLOYMENT_BLOCKER.md](CRITICAL_DEPLOYMENT_BLOCKER.md) - Load balancer restriction details

**Logs**:
- Lambda: `/aws/lambda/encryption-api`
- API Gateway: `/aws/apigateway/encryption-api`

**AWS Console**:
- Lambda: https://sa-east-1.console.aws.amazon.com/lambda/home?region=sa-east-1#/functions
- API Gateway: https://sa-east-1.console.aws.amazon.com/apigateway/home?region=sa-east-1
- RDS: https://sa-east-1.console.aws.amazon.com/rds/home?region=sa-east-1

---

**You're ready to deploy! Run `terraform apply` when ready.** 🚀
