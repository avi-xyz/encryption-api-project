# API Gateway Implementation Summary

## Overview

This document summarizes the implementation of AWS API Gateway as a workaround for the ALB (Application Load Balancer) restriction on your AWS account.

## Problem

Your AWS account has restrictions preventing the creation of Application Load Balancers in all regions. This blocked the initial deployment plan which relied on ALB for:
- HTTPS termination
- High availability
- Professional API endpoint
- Health checking

## Solution: API Gateway + Network Load Balancer

We implemented AWS API Gateway (HTTP API) with a VPC Link connecting to an internal Network Load Balancer, which fronts the ECS Fargate tasks.

### Architecture

```
Internet → API Gateway (Public) → VPC Link → NLB (Private) → ECS Tasks (Private Subnet) → RDS (Private Subnet)
```

### Components Added

1. **API Gateway HTTP API**
   - Protocol: HTTP API (cheaper than REST API)
   - CORS enabled
   - CloudWatch logging
   - Routes: POST /api/encrypt, GET /api/decrypt/{id}, GET /api/health

2. **VPC Link**
   - Connects API Gateway to private VPC resources
   - Attaches to private subnets
   - Uses ECS security group

3. **Network Load Balancer (Internal)**
   - Layer 4 (TCP) load balancer
   - Internal only (not internet-facing)
   - Targets ECS tasks on port 8080
   - TCP health checks

4. **Updated ECS Service**
   - Now in **private subnets** (more secure)
   - No public IP assignment
   - Registered with NLB target group
   - Security group allows traffic only from VPC

## Cost Analysis

### Monthly Costs (Estimated)

| Component | Cost/Month | Notes |
|-----------|------------|-------|
| **RDS MySQL (db.t3.micro)** | $15-20 | Database |
| **ECS Fargate (256 CPU, 1GB)** | $5-10 | 1 task running 24/7 |
| **NAT Gateway** | $30-35 | For ECS/RDS outbound |
| **NLB (Internal)** | $16-21 | 0.0225/hour × 720 hours |
| **API Gateway** | $0.35-3.50 | $3.50 per million requests |
| **VPC Link** | $0 | No charge for HTTP APIs |
| **Data Transfer** | Variable | Depends on usage |
| **TOTAL** | **$67-90/month** | At 100K-1M requests |

### Detailed Cost Breakdown

**API Gateway Pricing:**
- First 300 million requests: $1.00 per million
- HTTPS calls: $1.00 per million requests
- VPC Link: No charge (for HTTP APIs)

**Cost at different request volumes:**
- 100,000 requests/month: ~$0.10
- 1,000,000 requests/month: ~$1.00
- 10,000,000 requests/month: ~$10.00

**NLB Pricing:**
- $0.0225 per hour = $16.20/month
- LCU charges: ~$0.006 per LCU-hour
- Estimated LCU cost for light traffic: $5-8/month
- **Total NLB: ~$21-24/month**

### Cost Comparison: Options Considered

| Option | Monthly Cost | Pros | Cons |
|--------|--------------|------|------|
| **No Load Balancer** | $50-65 | Cheapest | No SSL, manual DNS, unstable IP |
| **ALB** | N/A | Best features | **Blocked on account** |
| **NLB Only** | $71-89 | High performance | No HTTP features, manual SSL |
| **API Gateway + NLB** | $67-90 | SSL, API management, professional | Slightly higher cost |

**Winner: API Gateway + NLB** - Best balance of features, cost, and security.

## Features Gained

### API Gateway Features
✅ **Built-in HTTPS/SSL** - Automatic SSL termination
✅ **CORS Support** - Pre-configured for web apps
✅ **CloudWatch Logging** - Request/response logging
✅ **Rate Limiting** - Can add throttling (future)
✅ **API Keys** - Can add authentication (future)
✅ **Caching** - Can enable response caching (future)
✅ **Custom Domain** - Can add custom domain (future)
✅ **WAF Integration** - Can add AWS WAF (future)

### Security Improvements
✅ **Private ECS Tasks** - No public IP exposure
✅ **VPC-only Access** - ECS only accessible via VPC Link
✅ **Security Group Restrictions** - Traffic only from VPC CIDR

### Operational Benefits
✅ **Automatic Scaling** - API Gateway scales automatically
✅ **No Certificate Management** - AWS handles SSL certs
✅ **Professional Endpoint** - Clean HTTPS API URL
✅ **Monitoring** - CloudWatch metrics and logs

## Configuration Changes

### Terraform Changes

1. **[main.tf](terraform/main.tf)**
   - Added `aws_lb` (NLB)
   - Added `aws_lb_target_group` (NLB target group)
   - Added `aws_lb_listener` (NLB listener)
   - Added `aws_apigatewayv2_vpc_link` (VPC Link)
   - Added `aws_apigatewayv2_api` (API Gateway HTTP API)
   - Added `aws_apigatewayv2_integration` (NLB integration)
   - Added `aws_apigatewayv2_route` (3 routes: encrypt, decrypt, health)
   - Added `aws_apigatewayv2_stage` (default stage with logging)
   - Added `aws_cloudwatch_log_group` (API Gateway logs)
   - Updated `aws_ecs_service` to use private subnets
   - Updated `aws_security_group.ecs` to allow VPC traffic only

2. **[outputs.tf](terraform/outputs.tf)**
   - Added `api_gateway_url` - Main API endpoint
   - Added `api_gateway_id` - Gateway ID for reference

3. **Security Group Changes**
   - ECS ingress: Changed from `0.0.0.0/0` to VPC CIDR (`10.0.0.0/16`)
   - ECS now in private subnets with no public IP

## Testing the Deployment

After deployment, the API will be accessible via API Gateway:

```bash
# Get the API Gateway URL
cd terraform
API_URL=$(terraform output -raw api_gateway_url)

# Test health endpoint
curl $API_URL/api/health

# Test encrypt endpoint
curl -X POST $API_URL/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from API Gateway!"}'

# Test decrypt endpoint (use ID from encrypt response)
curl $API_URL/api/decrypt/1
```

## Deployment Steps

1. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

2. **Review Plan**
   ```bash
   terraform plan
   ```

   Expected resources to create: ~40 resources including:
   - VPC, subnets, networking
   - RDS MySQL
   - ECS cluster and service
   - NLB and target group
   - API Gateway and VPC Link
   - Security groups and IAM roles

3. **Deploy Infrastructure**
   ```bash
   terraform apply -auto-approve
   ```

   Time: ~8-10 minutes

4. **Build and Push Docker Image**
   ```bash
   cd ..
   ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)

   # Login to ECR
   aws ecr get-login-password --region sa-east-1 | \
     docker login --username AWS --password-stdin $ECR_URL

   # Build for Linux/AMD64
   docker build --platform linux/amd64 -t encryption-api .
   docker tag encryption-api:latest $ECR_URL:latest
   docker push $ECR_URL:latest
   ```

5. **Deploy ECS Service**
   ```bash
   aws ecs update-service \
     --cluster encryption-api-cluster \
     --service encryption-api-service \
     --force-new-deployment \
     --region sa-east-1
   ```

6. **Get API URL**
   ```bash
   cd terraform
   terraform output api_gateway_url
   ```

## Monitoring

### CloudWatch Logs

1. **API Gateway Logs**: `/aws/apigateway/encryption-api`
   - Request/response logs
   - Error logs
   - Performance metrics

2. **ECS Application Logs**: `/ecs/encryption-api`
   - Application stdout/stderr
   - Spring Boot logs

### Metrics to Monitor

- API Gateway: Request count, latency, 4xx/5xx errors
- NLB: Healthy/unhealthy target count
- ECS: CPU, memory utilization
- RDS: Connections, query performance

## Future Enhancements

Once deployed, you can add:

1. **Custom Domain**
   ```terraform
   resource "aws_apigatewayv2_domain_name" "custom" {
     domain_name = "api.yourdomain.com"
     domain_name_configuration {
       certificate_arn = aws_acm_certificate.api.arn
       endpoint_type   = "REGIONAL"
       security_policy = "TLS_1_2"
     }
   }
   ```

2. **Rate Limiting**
   ```terraform
   resource "aws_apigatewayv2_route" "encrypt" {
     # ... existing config
     throttle_settings {
       burst_limit = 100
       rate_limit  = 50
     }
   }
   ```

3. **API Keys for Authentication**
   - Add Lambda authorizer
   - Or use API Gateway API keys

4. **Caching**
   - Enable for GET endpoints
   - Reduce backend load

## Cleanup

To avoid charges, always cleanup when done testing:

```bash
# Automated cleanup
./scripts/cleanup-aws.sh

# Or manual
cd terraform
terraform destroy -auto-approve
```

## Comparison: Before vs After

| Aspect | Before (ALB Blocked) | After (API Gateway) |
|--------|---------------------|---------------------|
| **Access** | Direct ECS public IP | API Gateway HTTPS URL |
| **SSL/TLS** | ❌ None | ✅ Automatic |
| **Security** | ⚠️ Public ECS tasks | ✅ Private ECS tasks |
| **Endpoint** | ⚠️ Changes on restart | ✅ Stable URL |
| **Cost** | $50-65/month | $67-90/month |
| **Features** | ❌ Basic | ✅ Professional API Gateway |
| **Monitoring** | ⚠️ ECS logs only | ✅ API Gateway + ECS logs |

## Summary

**Total Monthly Cost: $67-90**

This implementation provides a production-ready, secure, and cost-effective solution that works around the ALB restriction while actually providing **better features** than a standalone ALB would have given you:

- ✅ Professional API endpoint
- ✅ Built-in SSL/HTTPS
- ✅ Better security (private ECS)
- ✅ API management capabilities
- ✅ Only ~$17-25 more than no load balancer
- ✅ ~$4-7 cheaper than NLB-only solution

**Recommendation**: Deploy this configuration and test. If AWS Support approves ALB access in the future, you can migrate, but this solution is actually excellent for a REST API!
