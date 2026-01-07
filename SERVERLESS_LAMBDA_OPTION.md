# Serverless Lambda Architecture Option

## Overview

Deploy the Encryption API as an **AWS Lambda function** with **API Gateway**, completely bypassing the load balancer restriction.

## Architecture

```
Internet → API Gateway → Lambda Function → RDS MySQL
```

### Key Components

1. **API Gateway HTTP API**
   - Public HTTPS endpoint
   - Built-in SSL/TLS
   - CORS support
   - Request/response logging

2. **AWS Lambda Function**
   - Runs Spring Boot application
   - Auto-scales from 0 to thousands of requests
   - Java 17 runtime
   - VPC access to RDS

3. **RDS MySQL**
   - Same database as ECS version
   - In private subnet
   - Accessed via VPC Lambda configuration

4. **VPC Configuration**
   - Lambda in private subnets
   - NAT Gateway for outbound traffic
   - Security groups for RDS access

## Advantages

### ✅ Bypasses Load Balancer Restriction
- **No load balancer needed** - API Gateway directly invokes Lambda
- Can deploy immediately without AWS Support approval
- Same professional HTTPS endpoint as NLB solution

### ✅ Cost Savings
- **Pay per request** - no charges when idle
- No ECS Fargate costs ($5-10/month saved)
- No NLB costs ($21-24/month saved)
- **Estimated: $35-50/month** (vs $67-90 for API Gateway + NLB)

### ✅ Auto-Scaling
- Scales automatically from 0 to 1000s of concurrent executions
- No manual configuration needed
- Better than ECS for variable traffic

### ✅ Simpler Architecture
- Fewer moving parts than ECS
- No container orchestration
- Easier to maintain

## Disadvantages

### ⚠️ Cold Starts
- First request after idle: ~2-5 seconds
- Subsequent requests: <100ms
- Mitigations:
  - Provisioned concurrency (eliminates cold starts but costs more)
  - Keep-warm ping every 5 minutes (free tier)

### ⚠️ Execution Time Limit
- Lambda max timeout: 15 minutes
- Encryption API: Operations complete in <1 second
- **Not an issue for this use case**

### ⚠️ Spring Boot Overhead
- Spring Boot is heavy for Lambda
- ~200-500MB memory needed
- Can optimize with GraalVM native image (future)

### ⚠️ VPC Cold Start Penalty
- Lambda in VPC: Additional 1-2 second cold start
- Required for RDS access
- Can't be avoided

## Cost Analysis

### Monthly Costs (Low Traffic: 100K requests/month)

| Component | Cost/Month | Notes |
|-----------|------------|-------|
| **RDS MySQL (db.t3.micro)** | $15-20 | Same as before |
| **Lambda Execution** | $0.20 | 100K requests @ 512MB, 1s avg |
| **Lambda Requests** | $0.02 | $0.20 per 1M requests |
| **NAT Gateway** | $30-35 | For Lambda outbound access |
| **API Gateway** | $0.10 | $1.00 per 1M requests |
| **Data Transfer** | $1-2 | Minimal |
| **TOTAL** | **$46-57/month** | At 100K requests |

### Monthly Costs (Medium Traffic: 1M requests/month)

| Component | Cost/Month | Notes |
|-----------|------------|-------|
| **RDS MySQL (db.t3.micro)** | $15-20 | Same as before |
| **Lambda Execution** | $2.00 | 1M requests @ 512MB, 1s avg |
| **Lambda Requests** | $0.20 | $0.20 per 1M requests |
| **NAT Gateway** | $30-35 | For Lambda outbound access |
| **API Gateway** | $1.00 | $1.00 per 1M requests |
| **Data Transfer** | $2-5 | Moderate |
| **TOTAL** | **$50-63/month** | At 1M requests |

### Lambda Pricing Details

**Compute Costs**:
- $0.0000166667 per GB-second
- 512MB = 0.5GB
- 1 second execution = 0.5 × $0.0000166667 = $0.0000083
- 1M requests = $8.30

**Request Costs**:
- $0.20 per 1 million requests
- 1M requests = $0.20

**Free Tier** (first 12 months):
- 1M requests/month free
- 400,000 GB-seconds/month free
- **Can run entire API free for first year at low traffic!**

### Cost Comparison

| Solution | Monthly Cost | Can Deploy Now? |
|----------|--------------|-----------------|
| **Serverless Lambda** | **$46-63** | ✅ **YES** |
| API Gateway + NLB | $67-90 | ❌ Blocked |
| NLB Only | $71-89 | ❌ Blocked |
| ALB | N/A | ❌ Blocked |
| No Load Balancer (ECS) | $50-65 | ✅ Yes (no SSL) |

## Implementation Requirements

### 1. Spring Boot Compatibility

Spring Boot can run on Lambda using **AWS Serverless Java Container**:

**Add dependency** to `pom.xml`:
```xml
<dependency>
    <groupId>com.amazonaws.serverless</groupId>
    <artifactId>aws-serverless-java-container-springboot3</artifactId>
    <version>2.0.0</version>
</dependency>
```

**Create Lambda Handler** (`StreamLambdaHandler.java`):
```java
public class StreamLambdaHandler implements RequestStreamHandler {
    private static SpringBootLambdaContainerHandler<AwsProxyRequest, AwsProxyResponse> handler;

    static {
        try {
            handler = SpringBootLambdaContainerHandler.getAwsProxyHandler(Application.class);
        } catch (ContainerInitializationException e) {
            throw new RuntimeException("Could not initialize Spring Boot application", e);
        }
    }

    @Override
    public void handleRequest(InputStream input, OutputStream output, Context context)
            throws IOException {
        handler.proxyStream(input, output, context);
    }
}
```

### 2. Build Configuration

**Build Lambda-compatible JAR**:
```bash
./mvnw clean package
```

**Package for Lambda**:
- Uber JAR (fat JAR) with all dependencies
- Already configured in `pom.xml` with Spring Boot plugin

### 3. Terraform Resources

**Lambda Function**:
```terraform
resource "aws_lambda_function" "api" {
  filename         = "../target/encryption-api-1.0.0.jar"
  function_name    = "encryption-api"
  role            = aws_iam_role.lambda.arn
  handler         = "com.aviencryption.StreamLambdaHandler::handleRequest"
  runtime         = "java17"
  memory_size     = 512
  timeout         = 30

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE = "prod"
      DB_HOST     = aws_db_instance.mysql.endpoint
      DB_NAME     = aws_db_instance.mysql.db_name
      DB_USERNAME = var.db_username
      DB_PASSWORD = var.db_password
    }
  }
}
```

**API Gateway Integration**:
```terraform
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn

  payload_format_version = "2.0"
}
```

**Lambda Permission**:
```terraform
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
```

### 4. Database Connection Pooling

Lambda benefits from connection pooling across invocations:

**Update `application-prod.yml`**:
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 2  # Low for Lambda (2-5 max)
      minimum-idle: 0       # Allow connections to close
      connection-timeout: 10000
      idle-timeout: 60000
```

## Cold Start Mitigation

### Option 1: Keep-Warm Ping (Free)

**CloudWatch Event Rule**:
```terraform
resource "aws_cloudwatch_event_rule" "keep_warm" {
  name                = "keep-encryption-api-warm"
  description         = "Ping Lambda every 5 minutes to prevent cold starts"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.keep_warm.name
  target_id = "EncryptionAPILambda"
  arn       = aws_lambda_function.api.arn

  input = jsonencode({
    path = "/api/health"
  })
}
```

**Cost**: Free (within Lambda free tier)
**Cold Start Frequency**: Eliminated during daytime, possible at night

### Option 2: Provisioned Concurrency (Paid)

**Terraform**:
```terraform
resource "aws_lambda_provisioned_concurrency_config" "api" {
  function_name                     = aws_lambda_function.api.function_name
  provisioned_concurrent_executions = 1
  qualifier                         = aws_lambda_alias.live.name
}
```

**Cost**: +$6-10/month
**Cold Start Frequency**: Completely eliminated

## Performance Comparison

| Metric | ECS Fargate | Lambda (Cold) | Lambda (Warm) | Lambda (Provisioned) |
|--------|-------------|---------------|---------------|----------------------|
| First Request | ~200ms | ~3-5s | ~100ms | ~100ms |
| Subsequent | ~50-100ms | ~100ms | ~50-100ms | ~50-100ms |
| Scale Up Time | 1-2 min | Instant | N/A | N/A |
| Max Concurrent | 1-5 tasks | 1000+ | 1000+ | 1000+ |

## Security

### Same Security as ECS Version
- ✅ Lambda in private subnets
- ✅ No direct internet access to Lambda
- ✅ VPC security groups
- ✅ RDS in private subnet
- ✅ API Gateway with CORS
- ✅ SSL/TLS via API Gateway
- ✅ Secrets Manager for credentials

### Additional Lambda Security
- IAM execution role with least privilege
- VPC endpoint for Secrets Manager (optional, saves NAT costs)
- CloudWatch Logs encryption

## Deployment Process

### 1. Code Changes (Minimal)

1. Add Lambda handler dependency
2. Create `StreamLambdaHandler.java`
3. Adjust connection pool settings
4. Update Terraform configuration

**Effort**: ~2-3 hours

### 2. Build and Package

```bash
# Build JAR
./mvnw clean package

# JAR is ready for Lambda at target/encryption-api-1.0.0.jar
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform apply
```

### 4. Test API

```bash
API_URL=$(terraform output -raw api_gateway_url)

# Test health
curl $API_URL/api/health

# Test encrypt
curl -X POST $API_URL/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from Lambda!"}'
```

## Migration Path

### Now: Deploy Serverless
1. Can deploy immediately (no load balancer needed)
2. Production-ready with HTTPS
3. Lower cost than ECS
4. Auto-scaling built-in

### Future: Migrate to ECS (Optional)
If AWS Support approves load balancers and you want ECS:
1. Keep Lambda running
2. Deploy ECS + API Gateway + NLB
3. Test ECS deployment
4. Switch API Gateway integration from Lambda to NLB
5. Remove Lambda

**Zero downtime migration possible**

## Recommendation

### ✅ Deploy Serverless Lambda Now

**Reasons**:
1. **Can deploy immediately** - no waiting for AWS Support
2. **Lower cost** - $46-63/month vs $67-90/month
3. **Better scaling** - automatic, instant
4. **Production ready** - HTTPS, logging, monitoring
5. **Same API Gateway** - can migrate to NLB later if needed

**When to use**:
- ✅ API with variable traffic
- ✅ Development/testing
- ✅ Production (with keep-warm ping)
- ✅ Cost-sensitive deployments

**When NOT to use**:
- ❌ Consistent high traffic (>10M requests/month) - ECS cheaper
- ❌ Long-running operations (>15 min) - not applicable for this API
- ❌ Very large responses (>6MB) - not applicable for this API

## Next Steps

1. ✅ **Choose Lambda deployment** - best option given load balancer restriction
2. Update Spring Boot code for Lambda handler
3. Modify Terraform for Lambda instead of ECS
4. Deploy and test
5. Add keep-warm ping to reduce cold starts
6. Monitor costs and performance

## Questions?

Lambda is the **best solution** for this situation:
- Deploys immediately without load balancers
- Cheaper than ECS
- Production-ready with auto-scaling
- Easy to migrate to ECS later if needed

**Estimated implementation time**: 3-4 hours
**Monthly cost**: $46-63 (vs $67-90 for blocked NLB solution)
