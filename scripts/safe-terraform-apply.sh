#!/bin/bash

###############################################################################
# Safe Terraform Apply Script
#
# This script wraps terraform apply with automatic rollback on failure
# to prevent orphaned resources that incur costs.
#
# Usage:
#   chmod +x scripts/safe-terraform-apply.sh
#   ./scripts/safe-terraform-apply.sh
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Trap errors and cleanup
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Terraform apply failed with exit code $exit_code"
        print_warning "Initiating automatic cleanup to prevent orphaned resources..."

        # Run terraform destroy to cleanup any partially created resources
        print_info "Running terraform destroy to cleanup..."
        cd "$PROJECT_ROOT/terraform"
        terraform destroy -auto-approve || print_error "Cleanup failed - manual intervention required"

        print_error "Deployment failed and has been rolled back"
        exit $exit_code
    fi
}

trap cleanup_on_error EXIT

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

print_header "Safe Terraform Deployment"

###############################################################################
# Step 1: Validate Configuration
###############################################################################
print_header "Step 1: Validating Configuration"

if [ ! -f "terraform/terraform.tfvars" ]; then
    print_error "terraform/terraform.tfvars not found!"
    print_info "Please create it from terraform/terraform.tfvars.example"
    exit 1
fi

cd terraform

print_info "Running terraform validate..."
terraform validate

print_success "Configuration is valid"

###############################################################################
# Step 2: Initialize Terraform
###############################################################################
print_header "Step 2: Initializing Terraform"

terraform init

print_success "Terraform initialized"

###############################################################################
# Step 3: Plan Deployment
###############################################################################
print_header "Step 3: Planning Deployment"

print_info "Creating execution plan..."
terraform plan -out=tfplan

print_success "Plan created successfully"

###############################################################################
# Step 4: Review and Confirm
###############################################################################
print_header "Step 4: Review and Confirm"

echo ""
print_warning "COST WARNING:"
echo "This will create AWS resources that will incur charges:"
echo "  - RDS MySQL Database: ~\$15-20/month"
echo "  - ECS Fargate Tasks: ~\$5-10/month"
echo "  - NAT Gateway: ~\$30-35/month"
echo "  - Data Transfer: Variable"
echo ""
echo "Estimated Total: \$50-65/month"
echo ""

read -p "Do you want to proceed with deployment? (yes/no): " PROCEED

if [ "$PROCEED" != "yes" ]; then
    print_warning "Deployment cancelled by user"
    rm -f tfplan
    exit 0
fi

###############################################################################
# Step 5: Apply with Error Handling
###############################################################################
print_header "Step 5: Deploying Infrastructure"

print_info "Applying terraform plan..."
print_warning "If this fails, automatic rollback will be triggered"

# Apply the plan - if this fails, trap will trigger cleanup
terraform apply tfplan

# Remove the plan file
rm -f tfplan

print_success "Deployment completed successfully!"

# Disable the error trap since we succeeded
trap - EXIT

###############################################################################
# Step 6: Post-Deployment Verification
###############################################################################
print_header "Step 6: Post-Deployment Verification"

print_info "Verifying deployed resources..."

# Check if resources are created
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")

if [ -n "$ECR_URL" ] && [ -n "$RDS_ENDPOINT" ]; then
    print_success "Core resources verified"
else
    print_error "Some resources may not have been created properly"
    print_warning "Check terraform output for details"
fi

print_success "Deployment verification complete"

print_header "Next Steps"

echo "1. Build and push Docker image:"
echo "   cd $PROJECT_ROOT"
echo "   docker build --platform linux/amd64 -t encryption-api ."
echo "   docker tag encryption-api:latest $ECR_URL:latest"
echo ""
echo "2. Push to ECR:"
echo "   aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin $ECR_URL"
echo "   docker push $ECR_URL:latest"
echo ""
echo "3. Deploy to ECS:"
echo "   aws ecs update-service --cluster encryption-api-cluster --service encryption-api-service --force-new-deployment --region sa-east-1"
echo ""
echo "4. To cleanup everything when done:"
echo "   ./scripts/cleanup-aws.sh"
