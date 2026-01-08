#!/bin/bash

###############################################################################
# AWS Configuration Retrieval Script
#
# This script retrieves all necessary AWS infrastructure details needed for
# development after cloning the repository.
#
# Usage:
#   ./scripts/retrieve-aws-config.sh [--save]
#
# Options:
#   --save    Save output to a file (credentials-local.txt) - DO NOT COMMIT!
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SAVE_TO_FILE=false
OUTPUT_FILE="credentials-local.txt"

# Parse arguments
if [[ "$1" == "--save" ]]; then
    SAVE_TO_FILE=true
fi

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  AWS Infrastructure Configuration Retrieval${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Function to output both to console and optionally to file
output() {
    echo -e "$1"
    if [ "$SAVE_TO_FILE" = true ]; then
        echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$OUTPUT_FILE"
    fi
}

# Clear output file if saving
if [ "$SAVE_TO_FILE" = true ]; then
    > "$OUTPUT_FILE"
    output "# AWS Infrastructure Configuration"
    output "# Generated: $(date)"
    output "# WARNING: This file contains sensitive information - DO NOT COMMIT!"
    output ""
fi

# 1. Cognito User Pool ID
echo -e "${YELLOW}Retrieving Cognito User Pool ID...${NC}"
COGNITO_POOL_ID=$(aws cognito-idp list-user-pools --max-results 50 2>/dev/null | \
    jq -r '.UserPools[] | select(.Name | contains("encryption-api")) | .Id' | head -1)

if [ -n "$COGNITO_POOL_ID" ]; then
    output "${GREEN}✓${NC} Cognito User Pool ID: ${BLUE}$COGNITO_POOL_ID${NC}"

    # Get Cognito Client ID
    echo -e "${YELLOW}Retrieving Cognito Client ID...${NC}"
    COGNITO_CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
        --user-pool-id "$COGNITO_POOL_ID" 2>/dev/null | \
        jq -r '.UserPoolClients[0].ClientId')

    if [ -n "$COGNITO_CLIENT_ID" ] && [ "$COGNITO_CLIENT_ID" != "null" ]; then
        output "${GREEN}✓${NC} Cognito Client ID: ${BLUE}$COGNITO_CLIENT_ID${NC}"
    else
        output "${RED}✗${NC} Could not retrieve Cognito Client ID"
    fi
else
    output "${RED}✗${NC} Could not find Cognito User Pool"
fi

output ""

# 2. API Gateway URL
echo -e "${YELLOW}Retrieving API Gateway URL...${NC}"
API_URL=$(aws apigatewayv2 get-apis --region us-east-1 2>/dev/null | \
    jq -r '.Items[] | select(.Name | contains("encryption-api")) | .ApiEndpoint' | head -1)

if [ -n "$API_URL" ] && [ "$API_URL" != "null" ]; then
    output "${GREEN}✓${NC} API Gateway URL: ${BLUE}$API_URL${NC}"
else
    output "${RED}✗${NC} Could not retrieve API Gateway URL"
fi

output ""

# 3. Database Endpoint
echo -e "${YELLOW}Retrieving Database Endpoint...${NC}"
DB_ENDPOINT=$(aws rds describe-db-instances 2>/dev/null | \
    jq -r '.DBInstances[] | select(.DBInstanceIdentifier | contains("encryption-api")) | .Endpoint.Address' | head -1)

if [ -n "$DB_ENDPOINT" ] && [ "$DB_ENDPOINT" != "null" ]; then
    output "${GREEN}✓${NC} Database Endpoint: ${BLUE}$DB_ENDPOINT${NC}"

    # Get DB Instance Identifier
    DB_IDENTIFIER=$(aws rds describe-db-instances 2>/dev/null | \
        jq -r '.DBInstances[] | select(.DBInstanceIdentifier | contains("encryption-api")) | .DBInstanceIdentifier' | head -1)
    output "    DB Instance ID: ${BLUE}$DB_IDENTIFIER${NC}"
else
    output "${RED}✗${NC} Could not retrieve Database Endpoint"
fi

output ""

# 4. Secrets Manager - Database Password
echo -e "${YELLOW}Retrieving Database Password from Secrets Manager...${NC}"
DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id encryption-api-db-password 2>/dev/null | \
    jq -r '.SecretString' 2>/dev/null)

if [ -n "$DB_PASSWORD" ] && [ "$DB_PASSWORD" != "null" ]; then
    output "${GREEN}✓${NC} Database Password: ${BLUE}$DB_PASSWORD${NC}"
else
    output "${YELLOW}⚠${NC}  Could not retrieve database password from Secrets Manager"
    output "    Try: aws secretsmanager list-secrets | grep encryption"
fi

output ""

# 5. Secrets Manager - Master Encryption Key
echo -e "${YELLOW}Retrieving Master Encryption Key from Secrets Manager...${NC}"
MASTER_KEY=$(aws secretsmanager get-secret-value \
    --secret-id encryption-api-master-key 2>/dev/null | \
    jq -r '.SecretString' 2>/dev/null)

if [ -n "$MASTER_KEY" ] && [ "$MASTER_KEY" != "null" ]; then
    output "${GREEN}✓${NC} Master Encryption Key: ${BLUE}$MASTER_KEY${NC}"
else
    output "${YELLOW}⚠${NC}  Could not retrieve master key from Secrets Manager"
    output "    Try: aws secretsmanager list-secrets | grep encryption"
fi

output ""

# 6. S3 Lambda Code Bucket
echo -e "${YELLOW}Retrieving S3 Lambda Code Bucket...${NC}"
S3_BUCKET=$(aws s3 ls 2>/dev/null | grep encryption-api-lambda-code | awk '{print $3}' | head -1)

if [ -n "$S3_BUCKET" ]; then
    output "${GREEN}✓${NC} S3 Lambda Bucket: ${BLUE}$S3_BUCKET${NC}"
else
    output "${YELLOW}⚠${NC}  Could not find S3 Lambda code bucket"
fi

output ""

# 7. Terraform Outputs (if available)
if [ -f "terraform/terraform.tfstate" ]; then
    echo -e "${YELLOW}Retrieving Terraform Outputs...${NC}"
    cd terraform

    TF_API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
    TF_DB_ENDPOINT=$(terraform output -raw db_endpoint 2>/dev/null || echo "")
    TF_COGNITO_POOL=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "")

    if [ -n "$TF_API_URL" ]; then
        output "${GREEN}✓${NC} Terraform API URL: ${BLUE}$TF_API_URL${NC}"
    fi
    if [ -n "$TF_DB_ENDPOINT" ]; then
        output "${GREEN}✓${NC} Terraform DB Endpoint: ${BLUE}$TF_DB_ENDPOINT${NC}"
    fi
    if [ -n "$TF_COGNITO_POOL" ]; then
        output "${GREEN}✓${NC} Terraform Cognito Pool: ${BLUE}$TF_COGNITO_POOL${NC}"
    fi

    cd ..
    output ""
else
    output "${YELLOW}⚠${NC}  Terraform state not found (run terraform init/apply first)"
    output ""
fi

# Summary Section
output "${GREEN}==================================================${NC}"
output "${GREEN}  Configuration Summary${NC}"
output "${GREEN}==================================================${NC}"
output ""

if [ "$SAVE_TO_FILE" = true ]; then
    output "# Quick Reference for terraform.tfvars"
    output ""
    output "aws_region  = \"us-east-1\""
    output "environment = \"production\""
    output "project_name = \"encryption-api\""
    output ""
    if [ -n "$DB_PASSWORD" ] && [ "$DB_PASSWORD" != "null" ]; then
        output "db_username = \"admin\""
        output "db_password = \"$DB_PASSWORD\""
    else
        output "db_username = \"admin\""
        output "db_password = \"YOUR_SECURE_DB_PASSWORD_HERE\""
    fi
    output ""
    if [ -n "$MASTER_KEY" ] && [ "$MASTER_KEY" != "null" ]; then
        output "master_encryption_key = \"$MASTER_KEY\""
    else
        output "master_encryption_key = \"YOUR_BASE64_ENCODED_MASTER_KEY_HERE\""
    fi
    output ""
    output "# Environment Variables for Shell"
    output ""
fi

if [ -n "$COGNITO_POOL_ID" ]; then
    output "export COGNITO_USER_POOL_ID=\"$COGNITO_POOL_ID\""
fi
if [ -n "$COGNITO_CLIENT_ID" ] && [ "$COGNITO_CLIENT_ID" != "null" ]; then
    output "export COGNITO_CLIENT_ID=\"$COGNITO_CLIENT_ID\""
fi

output ""

if [ "$SAVE_TO_FILE" = true ]; then
    output "# Update these files with the values above:"
    output "# - terraform/terraform.tfvars"
    output "# - API_DOCUMENTATION.md (replace placeholder URLs and IDs)"
    output "# - README.md (replace placeholder URLs)"
    output "# - scripts/provision-api-user.sh (set COGNITO_USER_POOL_ID)"
    output ""
fi

echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo "1. Add environment variables to your shell profile:"
echo ""
if [ -n "$COGNITO_POOL_ID" ]; then
    echo "   echo 'export COGNITO_USER_POOL_ID=\"$COGNITO_POOL_ID\"' >> ~/.zshrc"
fi
if [ -n "$COGNITO_CLIENT_ID" ] && [ "$COGNITO_CLIENT_ID" != "null" ]; then
    echo "   echo 'export COGNITO_CLIENT_ID=\"$COGNITO_CLIENT_ID\"' >> ~/.zshrc"
fi
echo "   source ~/.zshrc"
echo ""
echo "2. Update terraform/terraform.tfvars with the values above"
echo ""
echo "3. Update documentation files (API_DOCUMENTATION.md, README.md)"
echo ""
if [ "$SAVE_TO_FILE" = true ]; then
    echo -e "${GREEN}✓${NC} Configuration saved to: ${BLUE}$OUTPUT_FILE${NC}"
    echo -e "${RED}⚠${NC}  ${YELLOW}WARNING: Do not commit $OUTPUT_FILE to git!${NC}"
    echo ""
fi

echo -e "${GREEN}Done!${NC}"
echo ""
