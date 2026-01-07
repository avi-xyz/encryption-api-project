# Deployment Guide - Encryption API

Complete guide to deploy this serverless Encryption API to your own AWS account.

---

## Prerequisites

### 1. Required Tools

Install the following on your local machine:

```bash
# macOS (using Homebrew)
brew install awscli terraform maven openjdk@17

# Verify installations
aws --version        # AWS CLI 2.x
terraform --version  # Terraform 1.x
mvn --version        # Maven 3.x
java --version       # Java 17
```

### 2. AWS Account Setup

You need:
- An AWS account with administrator access
- AWS CLI configured with your credentials

**Configure AWS CLI:**

```bash
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Output format: json
```

**Verify AWS access:**

```bash
aws sts get-caller-identity
# Should display your Account ID, UserId, and ARN
```

---

## Step-by-Step Deployment

### Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/encryption-api.git
cd encryption-api
```

### Step 2: Generate Secure Credentials

You need to generate secure credentials for:
1. Database password
2. Master encryption key

```bash
# Generate database password (24 characters)
openssl rand -base64 24
# Example output: nVhGfSr0PBteTmEO2jLUabcdefgh

# Generate master encryption key (32 bytes, base64 encoded)
openssl rand -base64 32
# Example output: lE/q+9LAjDtAYwDkTAWk7DOHctb81HWcEqUbAcM5+A4=

# Save these values - you'll need them in the next step!
```

### Step 3: Create Terraform Variables File

```bash
cd terraform

# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit the file with your values
nano terraform.tfvars  # or use your preferred editor
```

**Fill in `terraform.tfvars` with your values:**

```hcl
# AWS Configuration
aws_region  = "us-east-1"  # Change to your preferred region
environment = "production"

# Database Configuration
db_username = "admin"
db_password = "PASTE_YOUR_GENERATED_PASSWORD_HERE"

# Encryption Configuration
master_encryption_key = "PASTE_YOUR_GENERATED_KEY_HERE"

# S3 Bucket (must be globally unique)
s3_bucket_name = "encryption-api-lambda-yourname-20260107"

# Tags
project_name = "encryption-api"
```

**Important**: Replace `yourname` with something unique (your name, company, random string) to ensure the S3 bucket name is globally unique.

### Step 4: Build the Lambda JAR

```bash
# Go back to project root
cd ..

# Run the build script
./create-lambda-jar.sh
```

This script will:
- Build the Spring Boot application with Maven
- Restructure the JAR for AWS Lambda compatibility
- Create `target/encryption-api-lambda.jar`

**Expected output:**
```
BUILD SUCCESS
Lambda JAR created successfully: target/encryption-api-lambda.jar
```

### Step 5: Create S3 Bucket and Upload JAR

```bash
# Create S3 bucket (use the same name from terraform.tfvars)
aws s3 mb s3://encryption-api-lambda-yourname-20260107 --region us-east-1

# Upload the Lambda JAR
aws s3 cp target/encryption-api-lambda.jar \
  s3://encryption-api-lambda-yourname-20260107/encryption-api-1.0.0.jar \
  --region us-east-1
```

**Verify upload:**
```bash
aws s3 ls s3://encryption-api-lambda-yourname-20260107/
# Should show: encryption-api-1.0.0.jar
```

### Step 6: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform (downloads AWS provider)
terraform init

# Preview the infrastructure changes
terraform plan

# Deploy the infrastructure
terraform apply
```

**Review the plan carefully, then type `yes` to proceed.**

**Deployment takes approximately 10-15 minutes** due to:
- RDS MySQL instance creation (~8 minutes)
- NAT Gateway setup (~2 minutes)
- Lambda and API Gateway configuration (~2 minutes)
- VPC and networking setup (~3 minutes)

**Expected output:**
```
Apply complete! Resources: 37 added, 0 changed, 0 destroyed.

Outputs:
api_gateway_url = "https://abc123xyz.execute-api.us-east-1.amazonaws.com"
lambda_function_name = "encryption-api-function"
rds_endpoint = "encryption-api-db.xyz.us-east-1.rds.amazonaws.com:3306"
```

**Save these outputs!** You'll need the `api_gateway_url` to test your API.

---

## Step 7: View All Deployment Information (Automated)

**NEW**: Use the automated script to get all your deployment details in one command!

```bash
# Go back to project root
cd ..

# Run the deployment info script
./get-deployment-info.sh

# Or save to a file (deployment-info.txt is in .gitignore)
./get-deployment-info.sh --save
```

This script automatically retrieves and displays:
- ✅ API Gateway endpoint and ID
- ✅ Lambda function details (ARN, memory, runtime)
- ✅ RDS database endpoint and status
- ✅ VPC and NAT Gateway IDs
- ✅ S3 bucket name and size
- ✅ CloudWatch log group
- ✅ AWS Secrets Manager secrets
- ✅ Cost estimates
- ✅ Useful commands for monitoring and updates
- ✅ Live API health check

**Example output:**
```
🚀 ENCRYPTION API - DEPLOYMENT INFORMATION

📋 AWS ACCOUNT INFORMATION
  AWS Account ID:                YOUR-ACCOUNT-ID
  AWS Region:                    us-east-1

🌐 API GATEWAY
  API Gateway ID:                abc123xyz
  API Endpoint:                  https://abc123xyz.execute-api.us-east-1.amazonaws.com
  Health Check URL:              https://abc123xyz.execute-api.us-east-1.amazonaws.com/api/health

⚡ AWS LAMBDA FUNCTION
  Function Name:                 encryption-api-function
  Runtime:                       java17
  Memory Size:                   512 MB
  Timeout:                       30 seconds

🗄️  RDS MYSQL DATABASE
  DB Instance ID:                encryption-api-db
  Endpoint:                      encryption-api-db.xyz.us-east-1.rds.amazonaws.com:3306
  Status:                        available
  Engine:                        mysql 8.0.43

💰 ESTIMATED MONTHLY COST
  Total:                         $46-59/month
```

---

## Step 8: Test Your Deployment

### Quick Health Check

```bash
# Replace with your actual API Gateway URL from terraform output
export API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com"

# Test health endpoint
curl "$API_URL/api/health"
```

**Expected response:**
```json
{"status":"UP","timestamp":"2026-01-07T12:34:56.789"}
```

### Full API Test

```bash
# 1. Encrypt data
curl -X POST "$API_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from my deployment!"}'

# Expected response:
# {"id":1,"message":"Data encrypted and stored successfully","timestamp":"..."}

# 2. Decrypt data (use the ID from previous response)
curl "$API_URL/api/decrypt/1"

# Expected response:
# {"id":1,"plainText":"Hello from my deployment!","timestamp":"..."}
```

### Test Rate Limiting

```bash
# Run the rate limit test script
./test-rate-limit.sh

# Update the script first with your API URL:
# Edit test-rate-limit.sh and replace the API_URL
```

---

## Step 9: Monitor Your Deployment

### View Lambda Logs

```bash
# Stream Lambda logs in real-time
aws logs tail /aws/lambda/encryption-api-function --follow --region us-east-1
```

### Check Resource Status

```bash
# Lambda function
aws lambda get-function-configuration \
  --function-name encryption-api-function \
  --region us-east-1

# RDS database
aws rds describe-db-instances \
  --db-instance-identifier encryption-api-db \
  --region us-east-1

# API Gateway
aws apigatewayv2 get-apis --region us-east-1
```

### Cost Monitoring

Check your AWS Cost Explorer or set up billing alerts:

```bash
# Enable billing alerts (one-time setup)
aws cloudwatch put-metric-alarm \
  --alarm-name encryption-api-monthly-cost \
  --alarm-description "Alert when monthly cost exceeds $100" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

---

## Configuration Options

### Change AWS Region

To deploy in a different region:

1. Update `terraform/terraform.tfvars`:
   ```hcl
   aws_region = "eu-west-1"  # or any other region
   ```

2. Rebuild and redeploy:
   ```bash
   terraform apply
   ```

### Adjust Lambda Memory

Edit `terraform/main.tf`:

```hcl
resource "aws_lambda_function" "encryption_api" {
  memory_size = 1024  # Change from 512 to 1024 MB
  # ...
}
```

Then apply changes:
```bash
terraform apply
```

### Modify Rate Limits

Edit `terraform/main.tf` in the API Gateway throttle settings:

```hcl
resource "aws_apigatewayv2_stage" "default" {
  # ...
  default_route_settings {
    throttling_burst_limit = 10   # Change from 5
    throttling_rate_limit  = 10   # Change from 5
  }
}
```

### Change Database Size

Edit `terraform/main.tf`:

```hcl
resource "aws_db_instance" "encryption_db" {
  instance_class    = "db.t3.small"  # Upgrade from db.t3.micro
  allocated_storage = 50             # Increase from 20 GB
  # ...
}
```

---

## Troubleshooting

### Build Failures

**Problem**: Maven build fails

```bash
# Clean and rebuild
./mvnw clean package
./create-lambda-jar.sh
```

### Terraform Errors

**Problem**: "Bucket already exists"

Solution: Choose a different bucket name in `terraform.tfvars`

**Problem**: "Insufficient permissions"

Solution: Ensure your AWS user has administrator access or these permissions:
- AmazonEC2FullAccess
- AmazonVPCFullAccess
- AmazonRDSFullAccess
- AWSLambda_FullAccess
- AmazonAPIGatewayAdministrator
- IAMFullAccess
- AmazonS3FullAccess

### Lambda Cold Starts

**Problem**: First request takes 10+ seconds

This is normal! Subsequent requests will be fast (~50-100ms). The deployment includes a CloudWatch EventBridge rule that pings the Lambda every 5 minutes to keep it warm.

**To increase warm-up frequency**, edit `terraform/main.tf`:

```hcl
resource "aws_cloudwatch_event_rule" "lambda_warmup" {
  schedule_expression = "rate(2 minutes)"  # Change from 5 to 2 minutes
}
```

### API Returns 502 Bad Gateway

**Check Lambda logs:**
```bash
aws logs tail /aws/lambda/encryption-api-function --follow --region us-east-1
```

Common causes:
1. Database connection timeout (check RDS security group)
2. Lambda timeout (increase timeout in `terraform/main.tf`)
3. Incorrect environment variables

### Database Connection Issues

**Verify RDS endpoint:**
```bash
aws rds describe-db-instances \
  --db-instance-identifier encryption-api-db \
  --region us-east-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

**Check security groups allow Lambda → RDS traffic on port 3306**

---

## Updating Your Deployment

### Update Application Code

After making code changes:

```bash
# 1. Rebuild JAR
./create-lambda-jar.sh

# 2. Upload to S3
aws s3 cp target/encryption-api-lambda.jar \
  s3://encryption-api-lambda-yourname-20260107/encryption-api-1.0.0.jar \
  --region us-east-1

# 3. Update Lambda function
cd terraform
terraform apply
```

### Update Infrastructure

After changing Terraform files:

```bash
cd terraform
terraform plan   # Review changes
terraform apply  # Apply changes
```

---

## Cleanup and Destroy

**IMPORTANT**: To avoid ongoing AWS charges when you're done testing:

```bash
cd terraform

# Destroy all infrastructure
terraform destroy -auto-approve
```

This will delete:
- Lambda function
- API Gateway
- RDS MySQL database
- NAT Gateway
- VPC and all networking resources
- CloudWatch logs
- EventBridge rules

**Then delete the S3 bucket:**

```bash
aws s3 rb s3://encryption-api-lambda-yourname-20260107 --force --region us-east-1
```

**Cleanup time**: ~8-10 minutes

**Verify cleanup:**

```bash
# Check for remaining resources
aws lambda list-functions --region us-east-1 | grep encryption
aws rds describe-db-instances --region us-east-1 | grep encryption
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=encryption*"
```

---

## Cost Estimate

**Monthly cost for low-traffic deployment (~10,000 requests/month):**

| Service | Cost |
|---------|------|
| RDS MySQL (db.t3.micro) | $15-20 |
| NAT Gateway | $30-35 |
| Lambda (with free tier) | $0-1 |
| API Gateway | $0-1 |
| Data transfer | $1-2 |
| **Total** | **~$46-59/month** |

**First year with AWS Free Tier:**
- Lambda: 1M requests/month FREE
- RDS: 750 hours/month FREE (first 12 months)
- **Estimated first year**: ~$30-35/month (mostly NAT Gateway)

**Cost optimization tips:**
1. Use VPC endpoints instead of NAT Gateway (advanced setup)
2. Scale down RDS instance during non-business hours
3. Adjust Lambda memory based on actual usage
4. Use reserved instances for RDS if running long-term

---

## Production Recommendations

Before going to production, consider:

### 1. Security Enhancements

- [ ] Enable WAF (Web Application Firewall) on API Gateway
- [ ] Add API key authentication
- [ ] Implement JWT token validation
- [ ] Enable AWS CloudTrail for audit logging
- [ ] Rotate master encryption key regularly
- [ ] Enable RDS encryption at rest
- [ ] Use AWS Secrets Manager rotation

### 2. High Availability

- [ ] Deploy RDS in Multi-AZ configuration
- [ ] Set up CloudWatch alarms for errors and latency
- [ ] Configure Auto Scaling for Lambda (enabled by default)
- [ ] Set up CloudWatch Dashboard for monitoring

### 3. CI/CD Pipeline

- [ ] Set up GitHub Actions for automated deployments
- [ ] Add automated testing in pipeline
- [ ] Implement blue-green deployments
- [ ] Add integration tests

### 4. Custom Domain

```bash
# Request ACM certificate
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# After validation, attach to API Gateway in Terraform
```

---

## Support

### Documentation

- [README.md](README.md) - Project overview
- [DEPLOYMENT_SUCCESS.md](DEPLOYMENT_SUCCESS.md) - Detailed deployment walkthrough
- [LAMBDA_DEBUGGING_STATUS.md](LAMBDA_DEBUGGING_STATUS.md) - Troubleshooting guide
- [POSTMAN_TESTING_GUIDE.md](POSTMAN_TESTING_GUIDE.md) - API testing guide
- [AWS_CLEANUP_AUDIT.md](AWS_CLEANUP_AUDIT.md) - Resource cleanup guide

### Get Help

- **Issues**: [GitHub Issues](https://github.com/YOUR-USERNAME/encryption-api/issues)
- **AWS Documentation**: [AWS Lambda](https://docs.aws.amazon.com/lambda/) | [API Gateway](https://docs.aws.amazon.com/apigateway/)
- **Terraform Docs**: [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Next Steps

After successful deployment:

1. ✅ Test all API endpoints
2. ✅ Import Postman collection for comprehensive testing
3. ✅ Set up CloudWatch alarms
4. ✅ Configure billing alerts
5. ✅ Review and adjust rate limits
6. ✅ Plan production security enhancements
7. ✅ Set up monitoring dashboard

---

**Deployment Time**: 15-20 minutes
**Difficulty**: Intermediate
**Cost**: ~$46-59/month (lower with Free Tier)

**Status after following this guide**: ✅ Production-ready serverless API!

---

**Happy Deploying!** 🚀
