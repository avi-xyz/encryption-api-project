#!/bin/bash

##############################################################################
# Automated Deployment Script for Encryption API
#
# This script automates Steps 2-5 of the deployment process:
#   Step 2: Generate secure credentials
#   Step 3: Create terraform.tfvars
#   Step 4: Build Lambda JAR
#   Step 5: Create S3 bucket and upload JAR
#
# Usage: ./deploy.sh
#
# Prerequisites:
#   - AWS CLI configured (aws configure)
#   - Java 17 and Maven installed
#   - Terraform installed
##############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_REGION="us-east-1"
DEFAULT_ENVIRONMENT="production"
TERRAFORM_DIR="terraform"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"

# Print banner
print_banner() {
  echo ""
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║                                                            ║${NC}"
  echo -e "${CYAN}║       🚀 ENCRYPTION API - AUTOMATED DEPLOYMENT 🚀          ║${NC}"
  echo -e "${CYAN}║                                                            ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# Print section header
print_header() {
  echo ""
  echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${MAGENTA}$1${NC}"
  echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print step
print_step() {
  echo -e "${BLUE}▶ $1${NC}"
}

# Print success
print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Print warning
print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

# Print error
print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
  print_header "CHECKING PREREQUISITES"

  local all_good=true

  # Check AWS CLI
  print_step "Checking AWS CLI..."
  if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    echo "Install it with: brew install awscli"
    all_good=false
  else
    print_success "AWS CLI found: $(aws --version | head -n1)"
  fi

  # Check AWS credentials
  print_step "Checking AWS credentials..."
  if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured"
    echo "Run: aws configure"
    all_good=false
  else
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text)
    print_success "AWS credentials configured"
    echo "  Account ID: $AWS_ACCOUNT_ID"
    echo "  User/Role: $AWS_USER"
  fi

  # Check Java
  print_step "Checking Java..."
  if ! command -v java &> /dev/null; then
    print_error "Java is not installed"
    echo "Install it with: brew install openjdk@17"
    all_good=false
  else
    JAVA_VERSION=$(java -version 2>&1 | head -n1)
    print_success "Java found: $JAVA_VERSION"
  fi

  # Check Maven
  print_step "Checking Maven..."
  if ! command -v mvn &> /dev/null && ! [ -f "./mvnw" ]; then
    print_error "Maven is not installed"
    echo "Install it with: brew install maven"
    all_good=false
  else
    if [ -f "./mvnw" ]; then
      print_success "Maven wrapper found"
    else
      print_success "Maven found: $(mvn --version | head -n1)"
    fi
  fi

  # Check Terraform
  print_step "Checking Terraform..."
  if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    echo "Install it with: brew install terraform"
    all_good=false
  else
    print_success "Terraform found: $(terraform version | head -n1)"
  fi

  # Check openssl
  print_step "Checking OpenSSL..."
  if ! command -v openssl &> /dev/null; then
    print_error "OpenSSL is not installed"
    all_good=false
  else
    print_success "OpenSSL found"
  fi

  if [ "$all_good" = false ]; then
    echo ""
    print_error "Prerequisites check failed. Please install missing dependencies."
    exit 1
  fi

  echo ""
  print_success "All prerequisites satisfied!"
}

# Get user input
get_user_input() {
  print_header "CONFIGURATION"

  echo "This script will help you deploy the Encryption API to AWS."
  echo "Please provide the following information:"
  echo ""

  # AWS Region
  read -p "AWS Region (default: $DEFAULT_REGION): " AWS_REGION
  AWS_REGION=${AWS_REGION:-$DEFAULT_REGION}

  # Environment
  read -p "Environment (default: $DEFAULT_ENVIRONMENT): " ENVIRONMENT
  ENVIRONMENT=${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}

  # Generate unique bucket name suggestion
  TIMESTAMP=$(date +%Y%m%d)
  SUGGESTED_BUCKET="encryption-api-lambda-${AWS_ACCOUNT_ID:0:8}-${TIMESTAMP}"

  echo ""
  echo "S3 bucket name must be globally unique."
  read -p "S3 Bucket Name (default: $SUGGESTED_BUCKET): " S3_BUCKET
  S3_BUCKET=${S3_BUCKET:-$SUGGESTED_BUCKET}

  echo ""
  echo -e "${CYAN}Configuration Summary:${NC}"
  echo "  AWS Region:     $AWS_REGION"
  echo "  Environment:    $ENVIRONMENT"
  echo "  S3 Bucket:      $S3_BUCKET"
  echo "  AWS Account:    $AWS_ACCOUNT_ID"
  echo ""

  read -p "Proceed with deployment? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    echo "Deployment cancelled."
    exit 0
  fi
}

# Step 2: Generate secure credentials
generate_credentials() {
  print_header "STEP 2: GENERATING SECURE CREDENTIALS"

  print_step "Generating database password (24 characters)..."
  DB_PASSWORD=$(openssl rand -base64 24)
  print_success "Database password generated"

  print_step "Generating master encryption key (32 bytes, base64)..."
  MASTER_KEY=$(openssl rand -base64 32)
  print_success "Master encryption key generated"

  echo ""
  print_warning "IMPORTANT: Save these credentials securely!"
  echo ""
  echo -e "${YELLOW}Database Password:${NC} $DB_PASSWORD"
  echo -e "${YELLOW}Master Key:${NC} $MASTER_KEY"
  echo ""
  echo "These credentials will be saved to terraform/terraform.tfvars"
  echo "Press Enter to continue..."
  read
}

# Step 3: Create terraform.tfvars
create_tfvars() {
  print_header "STEP 3: CREATING TERRAFORM VARIABLES FILE"

  # Check if tfvars already exists
  if [ -f "$TFVARS_FILE" ]; then
    print_warning "terraform.tfvars already exists"
    read -p "Overwrite existing file? (yes/no): " OVERWRITE
    if [ "$OVERWRITE" != "yes" ] && [ "$OVERWRITE" != "y" ]; then
      print_warning "Keeping existing terraform.tfvars"
      return
    fi
  fi

  print_step "Creating $TFVARS_FILE..."

  cat > "$TFVARS_FILE" << EOF
# Terraform Variables for Encryption API
# Generated by deploy.sh on $(date)
# DO NOT commit this file to git!

# AWS Configuration
aws_region  = "$AWS_REGION"
environment = "$ENVIRONMENT"

# Database Configuration
db_username = "admin"
db_password = "$DB_PASSWORD"

# Encryption Configuration
master_encryption_key = "$MASTER_KEY"

# S3 Bucket (for Lambda code)
s3_bucket_name = "$S3_BUCKET"

# Tags
project_name = "encryption-api"
EOF

  chmod 600 "$TFVARS_FILE"  # Restrict permissions
  print_success "Created $TFVARS_FILE with secure permissions (600)"

  # Verify .gitignore
  if ! grep -q "terraform.tfvars" .gitignore 2>/dev/null; then
    print_warning "terraform.tfvars not in .gitignore - adding it now"
    echo "terraform/terraform.tfvars" >> .gitignore
  fi
}

# Step 4: Build Lambda JAR
build_lambda_jar() {
  print_header "STEP 4: BUILDING LAMBDA JAR"

  if [ ! -f "./create-lambda-jar.sh" ]; then
    print_error "create-lambda-jar.sh not found!"
    exit 1
  fi

  print_step "Running Maven build and JAR restructuring..."
  echo "This may take 2-3 minutes..."
  echo ""

  if ./create-lambda-jar.sh; then
    print_success "Lambda JAR built successfully"

    if [ -f "target/encryption-api-lambda.jar" ]; then
      JAR_SIZE=$(du -h target/encryption-api-lambda.jar | cut -f1)
      print_success "JAR file created: target/encryption-api-lambda.jar ($JAR_SIZE)"
    else
      print_error "JAR file not found after build"
      exit 1
    fi
  else
    print_error "Lambda JAR build failed"
    exit 1
  fi
}

# Step 5: Create S3 bucket and upload JAR
upload_to_s3() {
  print_header "STEP 5: CREATING S3 BUCKET AND UPLOADING JAR"

  # Check if bucket exists
  print_step "Checking if S3 bucket exists..."
  if aws s3 ls "s3://$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    print_warning "S3 bucket already exists: $S3_BUCKET"
  else
    print_step "Creating S3 bucket: $S3_BUCKET..."
    if aws s3 mb "s3://$S3_BUCKET" --region "$AWS_REGION"; then
      print_success "S3 bucket created"
    else
      print_error "Failed to create S3 bucket"
      echo "The bucket name might be taken. Try a different name."
      exit 1
    fi
  fi

  # Upload JAR
  print_step "Uploading JAR to S3..."
  if aws s3 cp target/encryption-api-lambda.jar \
      "s3://$S3_BUCKET/encryption-api-1.0.0.jar" \
      --region "$AWS_REGION"; then
    print_success "JAR uploaded to S3"

    # Verify upload
    S3_SIZE=$(aws s3 ls "s3://$S3_BUCKET/encryption-api-1.0.0.jar" --region "$AWS_REGION" | awk '{print $3}')
    print_success "Upload verified: encryption-api-1.0.0.jar ($S3_SIZE bytes)"
  else
    print_error "Failed to upload JAR to S3"
    exit 1
  fi
}

# Update terraform main.tf with S3 bucket name
update_terraform_config() {
  print_header "UPDATING TERRAFORM CONFIGURATION"

  print_step "Checking if Terraform configuration needs updates..."

  # Check if main.tf needs bucket name update
  MAIN_TF="$TERRAFORM_DIR/main.tf"

  if [ ! -f "$MAIN_TF" ]; then
    print_error "terraform/main.tf not found!"
    exit 1
  fi

  # Check if bucket name is hardcoded in main.tf
  if grep -q "s3_bucket.*=.*\"encryption-api-lambda-code" "$MAIN_TF" 2>/dev/null; then
    print_warning "S3 bucket name appears to be hardcoded in main.tf"
    print_warning "You may need to update it manually or ensure tfvars variable is used"
  fi

  print_success "Terraform configuration ready"
}

# Display next steps
show_next_steps() {
  print_header "✅ DEPLOYMENT PREPARATION COMPLETE!"

  echo ""
  echo -e "${GREEN}All prerequisites are ready. Now run Terraform to deploy:${NC}"
  echo ""
  echo -e "${CYAN}Step 6: Deploy Infrastructure${NC}"
  echo ""
  echo "  cd $TERRAFORM_DIR"
  echo "  terraform init"
  echo "  terraform plan    # Review the deployment plan"
  echo "  terraform apply   # Deploy (takes 10-15 minutes)"
  echo ""
  echo -e "${CYAN}Step 7: View Deployment Info${NC}"
  echo ""
  echo "  cd .."
  echo "  ./get-deployment-info.sh"
  echo ""
  echo -e "${CYAN}Step 8: Test Your API${NC}"
  echo ""
  echo "  # Get API URL from deployment info, then:"
  echo "  curl https://YOUR-API-ID.execute-api.$AWS_REGION.amazonaws.com/api/health"
  echo ""

  print_warning "IMPORTANT: Your credentials are saved in:"
  echo "  $TFVARS_FILE"
  echo ""
  echo "This file contains sensitive information and is excluded from git."
  echo "Make a secure backup if needed!"
  echo ""

  echo -e "${YELLOW}Estimated deployment time: 15-20 minutes${NC}"
  echo -e "${YELLOW}Estimated monthly cost: \$46-59 (with Free Tier: \$30-35)${NC}"
  echo ""
}

# Main execution
main() {
  print_banner

  # Run all steps
  check_prerequisites
  get_user_input
  generate_credentials
  create_tfvars
  build_lambda_jar
  upload_to_s3
  update_terraform_config
  show_next_steps

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}Ready to deploy! Follow the steps above to complete deployment.${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# Run main function
main
