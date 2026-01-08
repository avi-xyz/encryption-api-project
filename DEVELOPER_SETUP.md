# Developer Setup Guide

This guide helps you set up your local development environment after cloning this repository.

## Prerequisites

- Java 21+
- Maven 3.8+
- AWS CLI configured with appropriate credentials
- Docker Desktop (for local MySQL)
- Access to AWS Console (for retrieving infrastructure details)

## 1. Clone the Repository

```bash
git clone https://github.com/avi-xyz/encryption-api.git
cd encryption-api
```

## 2. Restore Terraform Variables

The repository contains a template file. You need to create the actual configuration:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Now edit `terraform/terraform.tfvars` and fill in your actual values:

```terraform
# AWS Configuration
aws_region  = "us-east-1"
environment = "production"
project_name = "encryption-api"

# Database Configuration
db_username = "admin"
db_password = "YOUR_ACTUAL_DB_PASSWORD"  # Get from AWS Secrets Manager or backup

# Encryption Configuration
master_encryption_key = "YOUR_ACTUAL_BASE64_KEY"  # Get from AWS Secrets Manager or backup
```

### Retrieving Values from AWS

#### Database Password

**Option 1: From AWS Secrets Manager**
```bash
aws secretsmanager get-secret-value \
  --secret-id encryption-api-db-password \
  --query SecretString \
  --output text
```

**Option 2: Reset the password** (if you don't have access to the original)
```bash
aws rds modify-db-instance \
  --db-instance-identifier encryption-api-db \
  --master-user-password "NewSecurePassword123!" \
  --apply-immediately
```

#### Master Encryption Key

**From AWS Secrets Manager:**
```bash
aws secretsmanager get-secret-value \
  --secret-id encryption-api-master-key \
  --query SecretString \
  --output text
```

**⚠️ WARNING**: If you change the encryption key, you won't be able to decrypt existing data!

## 3. Get AWS Infrastructure Details

You'll need these for various configuration files:

### Cognito User Pool ID

```bash
# List all user pools
aws cognito-idp list-user-pools --max-results 10

# Or get from Terraform state
cd terraform
terraform output cognito_user_pool_id
```

Example output: `us-east-1_D0eoSAzr8`

### Cognito Client ID

```bash
# Get client ID for your user pool
aws cognito-idp list-user-pool-clients \
  --user-pool-id us-east-1_D0eoSAzr8

# Or from Terraform
terraform output cognito_client_id
```

Example output: `4fks3earpocs8e9f03l5tj4n1g`

### API Gateway URL

```bash
# List APIs
aws apigatewayv2 get-apis --region us-east-1

# Or from Terraform
terraform output api_gateway_url
```

Example output: `https://3tyukwdl69.execute-api.us-east-1.amazonaws.com`

### RDS Database Endpoint

```bash
# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier encryption-api-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Or from Terraform
terraform output db_endpoint
```

Example output: `encryption-api-db.cy1m4iukgehr.us-east-1.rds.amazonaws.com`

## 4. Update Configuration Files

### Set Environment Variables for User Provisioning Script

```bash
export COGNITO_USER_POOL_ID="us-east-1_D0eoSAzr8"
export COGNITO_CLIENT_ID="4fks3earpocs8e9f03l5tj4n1g"
```

Add these to your `~/.zshrc` or `~/.bashrc` for persistence:

```bash
echo 'export COGNITO_USER_POOL_ID="us-east-1_D0eoSAzr8"' >> ~/.zshrc
echo 'export COGNITO_CLIENT_ID="4fks3earpocs8e9f03l5tj4n1g"' >> ~/.zshrc
source ~/.zshrc
```

### Update Application Configuration (Optional - for local testing)

If you want to test authentication locally, update `src/main/resources/application.yml`:

```yaml
cognito:
  region: us-east-1
  user-pool-id: us-east-1_D0eoSAzr8
  client-id: 4fks3earpocs8e9f03l5tj4n1g
```

## 5. Update Documentation Files

Replace placeholders in documentation with your actual values:

### API_DOCUMENTATION.md

Update these sections:
- Line 3: Base URL
- Lines 43, 51: User Pool ID in admin commands
- Lines 80, 104, 166, 205, 248: API Gateway URLs in examples

### README.md

Update these sections:
- Line 5: Live API URL
- Lines 46, 54: API Gateway URLs in quick start examples

### scripts/provision-api-user.sh

The script uses environment variables, but you can also hardcode if preferred:
- Line 33: `USER_POOL_ID` (or keep using environment variable)
- Lines 145, 156: API Gateway URLs in user instructions

## 6. Local Development Setup

For local development without AWS services:

```bash
# Start local MySQL with Docker
docker run -d \
  --name encryption-db \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=encryption_db \
  -e MYSQL_USER=admin \
  -e MYSQL_PASSWORD=password \
  -p 3306:3306 \
  mysql:8.0

# Run application locally
./mvnw spring-boot:run -Dspring-boot.run.profiles=test
```

## 7. Verify Your Setup

### Test Terraform Configuration

```bash
cd terraform
terraform init
terraform plan  # Should show no changes if infrastructure already exists
```

### Test User Provisioning Script

```bash
# Should show usage information
./scripts/provision-api-user.sh

# Test creating a user (if COGNITO_USER_POOL_ID is set)
./scripts/provision-api-user.sh test@example.com "Test User"
```

### Test API Access

```bash
# Health check
curl https://YOUR-API-GATEWAY-URL/api/health

# Login (after creating a test user)
curl -X POST https://YOUR-API-GATEWAY-URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test@example.com","password":"YOUR_PASSWORD"}'
```

## 8. Quick Reference: All Required Values

Create a secure note with these values for easy reference:

```
AWS Region: us-east-1
Environment: production

Cognito:
  User Pool ID: us-east-1_XXXXXXXXX
  Client ID: XXXXXXXXXXXXXXXXXXXXXXXXXX
  Region: us-east-1

API Gateway:
  URL: https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com

Database:
  Endpoint: encryption-api-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com
  Username: admin
  Password: [RETRIEVE FROM AWS SECRETS MANAGER]
  Database Name: encryption_db

Encryption:
  Master Key: [RETRIEVE FROM AWS SECRETS MANAGER]

S3:
  Lambda Code Bucket: encryption-api-lambda-code-useast1-YYYYMMDD
```

## 9. Security Best Practices

1. **Never commit credentials** - Always use the `.example` files as templates
2. **Use AWS Secrets Manager** - Store sensitive values there, not in code
3. **Rotate credentials regularly** - Especially database passwords and encryption keys
4. **Use environment variables** - For local development and CI/CD
5. **Enable MFA** - On your AWS account
6. **Audit AWS access** - Regularly review CloudTrail logs

## 10. Retrieving All Values with One Script

Save this as `scripts/retrieve-aws-config.sh`:

```bash
#!/bin/bash

echo "=== AWS Infrastructure Configuration ==="
echo ""

echo "Cognito User Pool ID:"
aws cognito-idp list-user-pools --max-results 10 | \
  jq -r '.UserPools[] | select(.Name | contains("encryption-api")) | .Id'
echo ""

echo "API Gateway URL:"
aws apigatewayv2 get-apis --region us-east-1 | \
  jq -r '.Items[] | select(.Name | contains("encryption-api")) | .ApiEndpoint'
echo ""

echo "Database Endpoint:"
aws rds describe-db-instances \
  --db-instance-identifier encryption-api-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
echo ""

echo "Database Password (from Secrets Manager):"
aws secretsmanager get-secret-value \
  --secret-id encryption-api-db-password \
  --query SecretString \
  --output text
echo ""

echo "Master Encryption Key (from Secrets Manager):"
aws secretsmanager get-secret-value \
  --secret-id encryption-api-master-key \
  --query SecretString \
  --output text
echo ""
```

Make it executable and run:

```bash
chmod +x scripts/retrieve-aws-config.sh
./scripts/retrieve-aws-config.sh
```

## Troubleshooting

### "Terraform state is out of sync"

```bash
cd terraform
terraform refresh
terraform state list
```

### "Cannot connect to database"

Check security groups allow your IP:
```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=encryption-api-db-sg"
```

### "Cognito user pool not found"

Verify the user pool exists:
```bash
aws cognito-idp describe-user-pool \
  --user-pool-id us-east-1_D0eoSAzr8
```

## Next Steps

After completing this setup:

1. Test the API locally with the test profile
2. Deploy any changes with `terraform apply`
3. Create test users with the provisioning script
4. Update documentation if you made any changes to infrastructure

---

**Need Help?** Check the main [README.md](README.md) for architecture details or [SECURITY.md](SECURITY.md) for security best practices.
