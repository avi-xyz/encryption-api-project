#!/bin/bash

##############################################################################
# Deployment Information Retrieval Script
#
# This script automatically retrieves all deployment details from your
# AWS account and displays them in a formatted table.
#
# Usage: ./get-deployment-info.sh [--save]
#   --save: Save output to deployment-info.txt (ignored by git)
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
LAMBDA_FUNCTION_NAME="encryption-api-function"
DB_INSTANCE_ID="encryption-api-db"
API_GATEWAY_NAME="encryption-api-gateway"
SAVE_TO_FILE=false

# Parse arguments
if [[ "$1" == "--save" ]]; then
  SAVE_TO_FILE=true
fi

# Function to print section headers
print_header() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print key-value pairs
print_info() {
  printf "${BLUE}%-30s${NC} %s\n" "$1:" "$2"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
  if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install it with: brew install awscli"
    exit 1
  fi

  if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured${NC}"
    echo "Run: aws configure"
    exit 1
  fi
}

# Start output capture if saving to file
if [ "$SAVE_TO_FILE" = true ]; then
  exec > >(tee deployment-info.txt)
fi

echo ""
print_header "🚀 ENCRYPTION API - DEPLOYMENT INFORMATION"
echo ""

# Check AWS CLI
echo -e "${YELLOW}Checking AWS CLI configuration...${NC}"
check_aws_cli
echo -e "${GREEN}✅ AWS CLI configured${NC}"
echo ""

# Get AWS Account Info
print_header "📋 AWS ACCOUNT INFORMATION"
echo ""

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "N/A")
AWS_USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "N/A")

print_info "AWS Account ID" "$AWS_ACCOUNT_ID"
print_info "AWS Region" "$AWS_REGION"
print_info "User/Role ARN" "$AWS_USER_ARN"
echo ""

# Get API Gateway Information
print_header "🌐 API GATEWAY"
echo ""

API_ID=$(aws apigatewayv2 get-apis \
  --region $AWS_REGION \
  --query "Items[?Name=='$API_GATEWAY_NAME'].ApiId" \
  --output text 2>/dev/null || echo "N/A")

if [ "$API_ID" != "N/A" ] && [ -n "$API_ID" ]; then
  API_ENDPOINT=$(aws apigatewayv2 get-apis \
    --region $AWS_REGION \
    --query "Items[?Name=='$API_GATEWAY_NAME'].ApiEndpoint" \
    --output text 2>/dev/null || echo "N/A")

  API_PROTOCOL=$(aws apigatewayv2 get-apis \
    --region $AWS_REGION \
    --query "Items[?Name=='$API_GATEWAY_NAME'].ProtocolType" \
    --output text 2>/dev/null || echo "N/A")

  print_info "API Gateway ID" "$API_ID"
  print_info "API Endpoint" "$API_ENDPOINT"
  print_info "Protocol Type" "$API_PROTOCOL"
  print_info "Health Check URL" "$API_ENDPOINT/api/health"
  print_info "Encrypt URL" "$API_ENDPOINT/api/encrypt"
  print_info "Decrypt URL" "$API_ENDPOINT/api/decrypt/{id}"
else
  echo -e "${YELLOW}⚠️  API Gateway not found${NC}"
fi
echo ""

# Get Lambda Information
print_header "⚡ AWS LAMBDA FUNCTION"
echo ""

LAMBDA_ARN=$(aws lambda get-function-configuration \
  --function-name $LAMBDA_FUNCTION_NAME \
  --region $AWS_REGION \
  --query 'FunctionArn' \
  --output text 2>/dev/null || echo "N/A")

if [ "$LAMBDA_ARN" != "N/A" ]; then
  LAMBDA_MEMORY=$(aws lambda get-function-configuration \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $AWS_REGION \
    --query 'MemorySize' \
    --output text 2>/dev/null || echo "N/A")

  LAMBDA_TIMEOUT=$(aws lambda get-function-configuration \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $AWS_REGION \
    --query 'Timeout' \
    --output text 2>/dev/null || echo "N/A")

  LAMBDA_RUNTIME=$(aws lambda get-function-configuration \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $AWS_REGION \
    --query 'Runtime' \
    --output text 2>/dev/null || echo "N/A")

  LAMBDA_LAST_MODIFIED=$(aws lambda get-function-configuration \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $AWS_REGION \
    --query 'LastModified' \
    --output text 2>/dev/null || echo "N/A")

  print_info "Function Name" "$LAMBDA_FUNCTION_NAME"
  print_info "Function ARN" "$LAMBDA_ARN"
  print_info "Runtime" "$LAMBDA_RUNTIME"
  print_info "Memory Size" "${LAMBDA_MEMORY} MB"
  print_info "Timeout" "${LAMBDA_TIMEOUT} seconds"
  print_info "Last Modified" "$LAMBDA_LAST_MODIFIED"
else
  echo -e "${YELLOW}⚠️  Lambda function not found${NC}"
fi
echo ""

# Get RDS Information
print_header "🗄️  RDS MYSQL DATABASE"
echo ""

RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_ID \
  --region $AWS_REGION \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text 2>/dev/null || echo "N/A")

if [ "$RDS_ENDPOINT" != "N/A" ]; then
  RDS_PORT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'DBInstances[0].Endpoint.Port' \
    --output text 2>/dev/null || echo "N/A")

  RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "N/A")

  RDS_ENGINE=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'DBInstances[0].Engine' \
    --output text 2>/dev/null || echo "N/A")

  RDS_VERSION=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'DBInstances[0].EngineVersion' \
    --output text 2>/dev/null || echo "N/A")

  RDS_INSTANCE_CLASS=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'DBInstances[0].DBInstanceClass' \
    --output text 2>/dev/null || echo "N/A")

  RDS_STORAGE=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'DBInstances[0].AllocatedStorage' \
    --output text 2>/dev/null || echo "N/A")

  RDS_MULTI_AZ=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'DBInstances[0].MultiAZ' \
    --output text 2>/dev/null || echo "N/A")

  print_info "DB Instance ID" "$DB_INSTANCE_ID"
  print_info "Endpoint" "$RDS_ENDPOINT:$RDS_PORT"
  print_info "Status" "$RDS_STATUS"
  print_info "Engine" "$RDS_ENGINE $RDS_VERSION"
  print_info "Instance Class" "$RDS_INSTANCE_CLASS"
  print_info "Storage" "${RDS_STORAGE} GB"
  print_info "Multi-AZ" "$RDS_MULTI_AZ"
else
  echo -e "${YELLOW}⚠️  RDS instance not found${NC}"
fi
echo ""

# Get VPC Information
print_header "🔒 VPC & NETWORKING"
echo ""

VPC_ID=$(aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=encryption-api-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "N/A")

if [ "$VPC_ID" != "N/A" ] && [ "$VPC_ID" != "None" ]; then
  VPC_CIDR=$(aws ec2 describe-vpcs \
    --region $AWS_REGION \
    --vpc-ids $VPC_ID \
    --query 'Vpcs[0].CidrBlock' \
    --output text 2>/dev/null || echo "N/A")

  NAT_GATEWAY_ID=$(aws ec2 describe-nat-gateways \
    --region $AWS_REGION \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || echo "N/A")

  print_info "VPC ID" "$VPC_ID"
  print_info "VPC CIDR Block" "$VPC_CIDR"
  print_info "NAT Gateway ID" "$NAT_GATEWAY_ID"
else
  echo -e "${YELLOW}⚠️  VPC not found${NC}"
fi
echo ""

# Get S3 Bucket Information
print_header "📦 S3 BUCKET (Lambda Code)"
echo ""

S3_BUCKET=$(aws s3 ls 2>/dev/null | grep encryption-api-lambda-code | awk '{print $3}' | head -n1 || echo "N/A")

if [ "$S3_BUCKET" != "N/A" ] && [ -n "$S3_BUCKET" ]; then
  S3_REGION=$(aws s3api get-bucket-location \
    --bucket $S3_BUCKET \
    --query 'LocationConstraint' \
    --output text 2>/dev/null || echo "us-east-1")

  # us-east-1 returns None, so handle that
  if [ "$S3_REGION" == "None" ]; then
    S3_REGION="us-east-1"
  fi

  S3_SIZE=$(aws s3 ls s3://$S3_BUCKET --recursive --human-readable --summarize 2>/dev/null | grep "Total Size" | awk '{print $3" "$4}' || echo "N/A")

  print_info "Bucket Name" "$S3_BUCKET"
  print_info "Region" "$S3_REGION"
  print_info "Total Size" "$S3_SIZE"
else
  echo -e "${YELLOW}⚠️  S3 bucket not found${NC}"
fi
echo ""

# Get CloudWatch Log Groups
print_header "📊 CLOUDWATCH LOGS"
echo ""

LOG_GROUP=$(aws logs describe-log-groups \
  --region $AWS_REGION \
  --log-group-name-prefix "/aws/lambda/$LAMBDA_FUNCTION_NAME" \
  --query 'logGroups[0].logGroupName' \
  --output text 2>/dev/null || echo "N/A")

if [ "$LOG_GROUP" != "N/A" ] && [ "$LOG_GROUP" != "None" ]; then
  LOG_SIZE=$(aws logs describe-log-groups \
    --region $AWS_REGION \
    --log-group-name-prefix "/aws/lambda/$LAMBDA_FUNCTION_NAME" \
    --query 'logGroups[0].storedBytes' \
    --output text 2>/dev/null || echo "N/A")

  # Convert bytes to MB
  if [ "$LOG_SIZE" != "N/A" ]; then
    LOG_SIZE_MB=$(echo "scale=2; $LOG_SIZE / 1024 / 1024" | bc)
    LOG_SIZE="${LOG_SIZE_MB} MB"
  fi

  print_info "Log Group" "$LOG_GROUP"
  print_info "Stored Size" "$LOG_SIZE"
  print_info "Tail Logs Command" "aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
else
  echo -e "${YELLOW}⚠️  CloudWatch log group not found${NC}"
fi
echo ""

# Get AWS Secrets
print_header "🔐 AWS SECRETS MANAGER"
echo ""

DB_SECRET=$(aws secretsmanager list-secrets \
  --region $AWS_REGION \
  --query "SecretList[?contains(Name, 'encryption-api-db-password')].Name" \
  --output text 2>/dev/null || echo "N/A")

MASTER_KEY_SECRET=$(aws secretsmanager list-secrets \
  --region $AWS_REGION \
  --query "SecretList[?contains(Name, 'encryption-api-master-key')].Name" \
  --output text 2>/dev/null || echo "N/A")

if [ "$DB_SECRET" != "N/A" ] && [ -n "$DB_SECRET" ]; then
  print_info "DB Password Secret" "$DB_SECRET"
else
  echo -e "${YELLOW}⚠️  DB password secret not found${NC}"
fi

if [ "$MASTER_KEY_SECRET" != "N/A" ] && [ -n "$MASTER_KEY_SECRET" ]; then
  print_info "Master Key Secret" "$MASTER_KEY_SECRET"
else
  echo -e "${YELLOW}⚠️  Master key secret not found${NC}"
fi
echo ""

# Quick API Test
if [ "$API_ENDPOINT" != "N/A" ] && [ -n "$API_ENDPOINT" ]; then
  print_header "✅ API HEALTH CHECK"
  echo ""

  echo -e "${YELLOW}Testing API endpoint...${NC}"
  HEALTH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$API_ENDPOINT/api/health" 2>/dev/null || echo "ERROR")

  HTTP_STATUS=$(echo "$HEALTH_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
  RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | grep -v "HTTP_STATUS")

  if [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}✅ API is healthy!${NC}"
    print_info "HTTP Status" "$HTTP_STATUS"
    print_info "Response" "$RESPONSE_BODY"
  else
    echo -e "${RED}❌ API health check failed${NC}"
    print_info "HTTP Status" "$HTTP_STATUS"
    print_info "Response" "$RESPONSE_BODY"
  fi
  echo ""
fi

# Cost Estimate
print_header "💰 ESTIMATED MONTHLY COST"
echo ""

echo -e "${BLUE}Based on current deployment:${NC}"
echo ""
printf "  %-30s %s\n" "RDS MySQL (db.t3.micro):" "\$15-20"
printf "  %-30s %s\n" "NAT Gateway:" "\$30-35"
printf "  %-30s %s\n" "Lambda (1M requests/month):" "\$0-2"
printf "  %-30s %s\n" "API Gateway:" "\$0-1"
printf "  %-30s %s\n" "Data transfer:" "\$1-2"
echo "  ────────────────────────────────────────"
printf "  ${GREEN}%-30s %s${NC}\n" "Total:" "\$46-59/month"
echo ""

# Useful Commands
print_header "🛠️  USEFUL COMMANDS"
echo ""

if [ "$API_ENDPOINT" != "N/A" ] && [ -n "$API_ENDPOINT" ]; then
  echo -e "${BLUE}Test Encrypt:${NC}"
  echo "  curl -X POST \"$API_ENDPOINT/api/encrypt\" \\"
  echo "    -H \"Content-Type: application/json\" \\"
  echo "    -d '{\"plainText\":\"test message\"}'"
  echo ""
fi

if [ "$LOG_GROUP" != "N/A" ] && [ "$LOG_GROUP" != "None" ]; then
  echo -e "${BLUE}View Lambda Logs:${NC}"
  echo "  aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
  echo ""
fi

echo -e "${BLUE}Update Lambda Code:${NC}"
echo "  ./create-lambda-jar.sh"
echo "  aws s3 cp target/encryption-api-lambda.jar s3://$S3_BUCKET/encryption-api-1.0.0.jar"
echo "  cd terraform && terraform apply"
echo ""

echo -e "${BLUE}Destroy Infrastructure:${NC}"
echo "  cd terraform && terraform destroy -auto-approve"
echo "  aws s3 rb s3://$S3_BUCKET --force --region $AWS_REGION"
echo ""

print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$SAVE_TO_FILE" = true ]; then
  echo -e "${GREEN}✅ Deployment information saved to: deployment-info.txt${NC}"
  echo ""
fi

echo -e "${GREEN}Deployment information retrieved successfully!${NC}"
echo ""
