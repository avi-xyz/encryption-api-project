#!/bin/bash

###############################################################################
# Encryption API - Automated AWS Deployment Script
#
# This script automates the complete deployment to AWS:
# - Checks prerequisites
# - Configures AWS credentials
# - Generates encryption keys
# - Sets up Terraform variables
# - Deploys infrastructure
# - Builds and pushes Docker image
# - Deploys to ECS
# - Tests the deployment
#
# Usage:
#   chmod +x scripts/deploy-to-aws.sh
#   ./scripts/deploy-to-aws.sh
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

print_header "Encryption API - AWS Deployment"

###############################################################################
# Step 1: Check Prerequisites
###############################################################################
print_header "Step 1: Checking Prerequisites"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed!"
    print_info "Install it with: brew install awscli"
    exit 1
fi
print_success "AWS CLI is installed"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed!"
    print_info "Install it with: brew install terraform"
    exit 1
fi
print_success "Terraform is installed"

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    print_info "Install it with: brew install --cask docker"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker is not running!"
    print_info "Start Docker Desktop and try again"
    exit 1
fi
print_success "Docker is running"

###############################################################################
# Step 2: Configure AWS Credentials
###############################################################################
print_header "Step 2: AWS Credentials"

# Check if AWS credentials are configured
if aws sts get-caller-identity &> /dev/null; then
    print_success "AWS credentials are already configured"
    aws sts get-caller-identity
    echo ""
    read -p "Do you want to reconfigure AWS credentials? (y/N): " reconfigure
    if [[ $reconfigure =~ ^[Yy]$ ]]; then
        aws configure
    fi
else
    print_warning "AWS credentials not found"
    print_info "You'll need your AWS Access Key ID and Secret Access Key"
    print_info "Get them from: AWS Console → IAM → Users → Security credentials"
    echo ""
    read -p "Press Enter to configure AWS credentials..."
    aws configure
fi

# Verify credentials work
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "Failed to authenticate with AWS!"
    exit 1
fi

print_success "AWS credentials verified"

###############################################################################
# Step 3: Get Deployment Configuration
###############################################################################
print_header "Step 3: Deployment Configuration"

# Get AWS region
echo ""
print_info "AWS Region Configuration"
read -p "Enter AWS region [us-east-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# Get environment name
echo ""
print_info "Environment Configuration"
read -p "Enter environment name (development/staging/production) [development]: " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-development}

# Get database password
echo ""
print_info "Database Password"
print_warning "Create a strong password for the RDS MySQL database"
while true; do
    read -sp "Enter database password (min 8 chars): " DB_PASSWORD
    echo ""
    if [ ${#DB_PASSWORD} -lt 8 ]; then
        print_error "Password must be at least 8 characters long"
        continue
    fi
    read -sp "Confirm database password: " DB_PASSWORD_CONFIRM
    echo ""
    if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
        break
    else
        print_error "Passwords do not match. Please try again."
    fi
done
print_success "Database password set"

# Generate master encryption key
echo ""
print_info "Generating master encryption key..."
MASTER_KEY=$(openssl rand -base64 32)
print_success "Master encryption key generated"
print_info "Key: $MASTER_KEY"

# Get ECS configuration
echo ""
print_info "ECS Task Configuration"
read -p "Enter CPU units (256/512/1024/2048) [512]: " ECS_CPU
ECS_CPU=${ECS_CPU:-512}

read -p "Enter Memory in MB (512/1024/2048/4096) [1024]: " ECS_MEMORY
ECS_MEMORY=${ECS_MEMORY:-1024}

read -p "Enter desired task count [1]: " ECS_COUNT
ECS_COUNT=${ECS_COUNT:-1}

###############################################################################
# Step 4: Create Terraform Variables File
###############################################################################
print_header "Step 4: Creating Terraform Configuration"

cd terraform

cat > terraform.tfvars << EOF
# Terraform Variables for Encryption API
# Auto-generated by deploy-to-aws.sh
# Generated at: $(date)

aws_region  = "$AWS_REGION"
environment = "$ENVIRONMENT"

# Database Configuration
db_username = "admin"
db_password = "$DB_PASSWORD"

# Master Encryption Key
master_encryption_key = "$MASTER_KEY"

# ECS Configuration
ecs_task_cpu      = "$ECS_CPU"
ecs_task_memory   = "$ECS_MEMORY"
ecs_desired_count = $ECS_COUNT
EOF

print_success "Terraform variables configured"

###############################################################################
# Step 5: Initialize Terraform
###############################################################################
print_header "Step 5: Initializing Terraform"

terraform init
print_success "Terraform initialized"

###############################################################################
# Step 6: Review Deployment Plan
###############################################################################
print_header "Step 6: Reviewing Deployment Plan"

print_info "Running terraform plan..."
terraform plan

echo ""
print_warning "This will create AWS resources that will incur costs!"
print_info "Estimated cost: \$20-30/month for development environment"
echo ""
read -p "Do you want to proceed with deployment? (yes/no): " PROCEED

if [ "$PROCEED" != "yes" ]; then
    print_warning "Deployment cancelled by user"
    exit 0
fi

###############################################################################
# Step 7: Deploy Infrastructure
###############################################################################
print_header "Step 7: Deploying Infrastructure to AWS"

print_info "This will take approximately 10-15 minutes..."
print_info "Creating: VPC, RDS, ECS, ALB, Security Groups, IAM Roles, etc."

terraform apply -auto-approve

print_success "Infrastructure deployed successfully!"

# Get outputs
ECR_URL=$(terraform output -raw ecr_repository_url)
ALB_URL=$(terraform output -raw alb_url)

###############################################################################
# Step 8: Build Docker Image
###############################################################################
print_header "Step 8: Building Docker Image"

cd "$PROJECT_ROOT"

print_info "Building Docker image..."
docker build -t encryption-api .

print_success "Docker image built successfully"

###############################################################################
# Step 9: Push to ECR
###############################################################################
print_header "Step 9: Pushing to Amazon ECR"

print_info "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL

print_info "Tagging image..."
docker tag encryption-api:latest $ECR_URL:latest

print_info "Pushing image to ECR (this may take a few minutes)..."
docker push $ECR_URL:latest

print_success "Docker image pushed to ECR"

###############################################################################
# Step 10: Deploy to ECS
###############################################################################
print_header "Step 10: Deploying to ECS"

print_info "Triggering ECS deployment..."
aws ecs update-service \
  --cluster encryption-api-cluster \
  --service encryption-api-service \
  --force-new-deployment \
  --region $AWS_REGION \
  > /dev/null

print_success "ECS deployment triggered"

print_info "Waiting for service to stabilize (this takes 2-3 minutes)..."
aws ecs wait services-stable \
  --cluster encryption-api-cluster \
  --services encryption-api-service \
  --region $AWS_REGION

print_success "ECS service is stable and running"

###############################################################################
# Step 11: Test Deployment
###############################################################################
print_header "Step 11: Testing Deployment"

print_info "Waiting 30 seconds for health checks..."
sleep 30

print_info "Testing health endpoint..."
if curl -f -s "http://$ALB_URL/api/health" > /dev/null; then
    print_success "Health check passed!"
else
    print_warning "Health check failed - service may still be starting"
fi

print_info "Testing encrypt endpoint..."
ENCRYPT_RESPONSE=$(curl -s -X POST "http://$ALB_URL/api/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from AWS!"}')

if echo "$ENCRYPT_RESPONSE" | grep -q "id"; then
    print_success "Encryption test passed!"
    ENCRYPTED_ID=$(echo "$ENCRYPT_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

    print_info "Testing decrypt endpoint..."
    DECRYPT_RESPONSE=$(curl -s "http://$ALB_URL/api/decrypt/$ENCRYPTED_ID")

    if echo "$DECRYPT_RESPONSE" | grep -q "Hello from AWS"; then
        print_success "Decryption test passed!"
    else
        print_warning "Decryption test failed"
    fi
else
    print_warning "Encryption test failed"
fi

###############################################################################
# Deployment Complete
###############################################################################
print_header "Deployment Complete!"

cat << EOF

${GREEN}✓ Your Encryption API is now live on AWS!${NC}

${BLUE}Deployment Details:${NC}
  Region:      $AWS_REGION
  Environment: $ENVIRONMENT
  ECS Tasks:   $ECS_COUNT
  CPU/Memory:  $ECS_CPU/$ECS_MEMORY

${BLUE}Application URL:${NC}
  ${YELLOW}http://$ALB_URL${NC}

${BLUE}API Endpoints:${NC}
  Health:  ${YELLOW}http://$ALB_URL/api/health${NC}
  Encrypt: ${YELLOW}http://$ALB_URL/api/encrypt${NC}
  Decrypt: ${YELLOW}http://$ALB_URL/api/decrypt/{id}${NC}

${BLUE}Test Commands:${NC}
  ${YELLOW}# Health check
  curl http://$ALB_URL/api/health

  # Encrypt data
  curl -X POST http://$ALB_URL/api/encrypt \\
    -H "Content-Type: application/json" \\
    -d '{"plainText":"Your secret message"}'

  # Decrypt data (replace 1 with actual ID)
  curl http://$ALB_URL/api/decrypt/1${NC}

${BLUE}Monitoring Commands:${NC}
  ${YELLOW}# View logs
  aws logs tail /ecs/encryption-api --follow --region $AWS_REGION

  # Check service status
  aws ecs describe-services \\
    --cluster encryption-api-cluster \\
    --services encryption-api-service \\
    --region $AWS_REGION${NC}

${BLUE}Update Deployment:${NC}
  ${YELLOW}# After code changes, run:
  cd $PROJECT_ROOT
  docker build -t encryption-api .
  docker tag encryption-api:latest $ECR_URL:latest
  docker push $ECR_URL:latest
  aws ecs update-service \\
    --cluster encryption-api-cluster \\
    --service encryption-api-service \\
    --force-new-deployment \\
    --region $AWS_REGION${NC}

${BLUE}Cleanup (Delete Everything):${NC}
  ${YELLOW}cd terraform
  terraform destroy${NC}

${BLUE}Important Files Created:${NC}
  - terraform/terraform.tfvars (contains secrets - DO NOT commit!)

${BLUE}Estimated Monthly Cost:${NC}
  Development: ~\$20-30/month
  Production:  ~\$50-100/month

${BLUE}Next Steps:${NC}
  1. Save your configuration (especially the master encryption key)
  2. Set up SSL/TLS certificate in AWS Certificate Manager (optional)
  3. Configure custom domain name (optional)
  4. Set up CloudWatch alarms for monitoring
  5. Enable Multi-AZ for production workloads

${GREEN}Happy deploying! 🚀${NC}

EOF

# Save deployment info
cat > deployment-info.txt << EOF
Deployment Date: $(date)
AWS Region: $AWS_REGION
Environment: $ENVIRONMENT
Application URL: http://$ALB_URL
ECR Repository: $ECR_URL
Master Encryption Key: $MASTER_KEY

DO NOT COMMIT THIS FILE TO VERSION CONTROL!
EOF

print_success "Deployment information saved to deployment-info.txt"
