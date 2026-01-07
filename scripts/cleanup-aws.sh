#!/bin/bash

###############################################################################
# AWS Resource Cleanup Script
#
# This script safely removes all AWS resources created for the Encryption API,
# including orphaned resources from failed deployments.
#
# Usage:
#   chmod +x scripts/cleanup-aws.sh
#   ./scripts/cleanup-aws.sh [--region us-west-2]
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

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Default region (changed to sa-east-1 where ALB works)
REGION="${1:-sa-east-1}"

print_header "AWS Cleanup Script - Encryption API"

echo "This script will delete ALL AWS resources for the Encryption API project."
echo "Region: $REGION"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_warning "Cleanup cancelled by user"
    exit 0
fi

###############################################################################
# Step 1: Terraform Destroy
###############################################################################
print_header "Step 1: Terraform Destroy"

if [ -d "terraform" ] && [ -f "terraform/main.tf" ]; then
    cd terraform

    if [ -f "terraform.tfstate" ]; then
        print_info "Running terraform destroy..."

        # Delete ECR images first to avoid errors
        ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null | cut -d'/' -f2 || echo "")
        if [ -n "$ECR_REPO" ]; then
            print_info "Deleting Docker images from ECR..."
            aws ecr batch-delete-image \
                --repository-name "$ECR_REPO" \
                --region "$REGION" \
                --image-ids "$(aws ecr list-images --repository-name "$ECR_REPO" --region "$REGION" --query 'imageIds[*]' --output json 2>/dev/null)" \
                2>/dev/null || print_warning "No images to delete or ECR repo doesn't exist"
        fi

        terraform destroy -auto-approve
        print_success "Terraform resources destroyed"
    else
        print_warning "No terraform.tfstate found, skipping terraform destroy"
    fi

    cd "$PROJECT_ROOT"
else
    print_warning "No terraform directory found"
fi

###############################################################################
# Step 2: Clean Orphaned Resources
###############################################################################
print_header "Step 2: Cleaning Orphaned Resources"

# Function to delete resources with tag filter
delete_tagged_resources() {
    local resource_type=$1
    local delete_command=$2

    print_info "Checking for orphaned $resource_type..."
    # Implementation will be added based on resource type
}

# Delete orphaned NAT Gateways
print_info "Checking for orphaned NAT Gateways..."
NAT_GWS=$(aws ec2 describe-nat-gateways --region "$REGION" \
    --filter "Name=tag:Project,Values=encryption-api" "Name=state,Values=available" \
    --query 'NatGateways[*].NatGatewayId' --output text)

for NAT_ID in $NAT_GWS; do
    if [ -n "$NAT_ID" ]; then
        print_info "Deleting NAT Gateway: $NAT_ID"
        aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID" --region "$REGION"
        print_success "NAT Gateway $NAT_ID marked for deletion"
    fi
done

# Wait for NAT Gateways to delete
if [ -n "$NAT_GWS" ]; then
    print_info "Waiting for NAT Gateways to delete (this takes ~2 minutes)..."
    for NAT_ID in $NAT_GWS; do
        while [ "$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT_ID" --region "$REGION" --query 'NatGateways[0].State' --output text 2>/dev/null || echo 'deleted')" != "deleted" ]; do
            echo -n "."
            sleep 5
        done
    done
    echo ""
    print_success "NAT Gateways deleted"
fi

# Delete orphaned Elastic IPs
print_info "Checking for orphaned Elastic IPs..."
EIP_ALLOCS=$(aws ec2 describe-addresses --region "$REGION" \
    --filters "Name=tag:Project,Values=encryption-api" \
    --query 'Addresses[*].AllocationId' --output text)

for EIP_ID in $EIP_ALLOCS; do
    if [ -n "$EIP_ID" ]; then
        print_info "Releasing Elastic IP: $EIP_ID"
        aws ec2 release-address --allocation-id "$EIP_ID" --region "$REGION" 2>/dev/null || \
            print_warning "Could not release $EIP_ID (may already be released)"
    fi
done

if [ -n "$EIP_ALLOCS" ]; then
    print_success "Elastic IPs released"
fi

# Delete orphaned ECS Clusters
print_info "Checking for orphaned ECS Clusters..."
ECS_CLUSTERS=$(aws ecs list-clusters --region "$REGION" \
    --query 'clusterArns[?contains(@, `encryption-api`)]' --output text)

for CLUSTER_ARN in $ECS_CLUSTERS; do
    if [ -n "$CLUSTER_ARN" ]; then
        CLUSTER_NAME=$(echo "$CLUSTER_ARN" | rev | cut -d'/' -f1 | rev)

        # Stop all tasks first
        print_info "Stopping tasks in cluster: $CLUSTER_NAME"
        TASKS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --region "$REGION" --query 'taskArns[*]' --output text)
        for TASK in $TASKS; do
            aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$TASK" --region "$REGION" >/dev/null 2>&1
        done

        # Delete services
        SERVICES=$(aws ecs list-services --cluster "$CLUSTER_NAME" --region "$REGION" --query 'serviceArns[*]' --output text)
        for SERVICE in $SERVICES; do
            print_info "Deleting service: $SERVICE"
            aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE" --desired-count 0 --region "$REGION" >/dev/null 2>&1
            aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE" --force --region "$REGION" >/dev/null 2>&1
        done

        # Delete cluster
        print_info "Deleting cluster: $CLUSTER_NAME"
        aws ecs delete-cluster --cluster "$CLUSTER_NAME" --region "$REGION"
        print_success "ECS Cluster $CLUSTER_NAME deleted"
    fi
done

# Delete orphaned RDS Instances
print_info "Checking for orphaned RDS Instances..."
RDS_INSTANCES=$(aws rds describe-db-instances --region "$REGION" \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `encryption-api`)].DBInstanceIdentifier' --output text)

for DB_ID in $RDS_INSTANCES; do
    if [ -n "$DB_ID" ]; then
        print_info "Deleting RDS Instance: $DB_ID (this takes ~5 minutes)..."
        aws rds delete-db-instance \
            --db-instance-identifier "$DB_ID" \
            --skip-final-snapshot \
            --delete-automated-backups \
            --region "$REGION" 2>/dev/null || \
            print_warning "Could not delete $DB_ID (may already be deleting)"
    fi
done

# Delete orphaned VPCs
print_info "Checking for orphaned VPCs..."
VPCS=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Project,Values=encryption-api" \
    --query 'Vpcs[*].VpcId' --output text)

for VPC_ID in $VPCS; do
    if [ -n "$VPC_ID" ]; then
        print_info "Cleaning up VPC: $VPC_ID"

        # Delete Internet Gateways
        IGWS=$(aws ec2 describe-internet-gateways --region "$REGION" \
            --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
            --query 'InternetGateways[*].InternetGatewayId' --output text)
        for IGW in $IGWS; do
            aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" --region "$REGION"
            aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" --region "$REGION"
        done

        # Delete Subnets
        SUBNETS=$(aws ec2 describe-subnets --region "$REGION" \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'Subnets[*].SubnetId' --output text)
        for SUBNET in $SUBNETS; do
            aws ec2 delete-subnet --subnet-id "$SUBNET" --region "$REGION" 2>/dev/null || true
        done

        # Delete Security Groups (except default)
        SGS=$(aws ec2 describe-security-groups --region "$REGION" \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
        for SG in $SGS; do
            aws ec2 delete-security-group --group-id "$SG" --region "$REGION" 2>/dev/null || true
        done

        # Delete Route Tables (except main)
        RTBS=$(aws ec2 describe-route-tables --region "$REGION" \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' --output text)
        for RTB in $RTBS; do
            aws ec2 delete-route-table --route-table-id "$RTB" --region "$REGION" 2>/dev/null || true
        done

        # Delete VPC
        aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null && \
            print_success "VPC $VPC_ID deleted" || \
            print_warning "Could not delete VPC $VPC_ID (may have remaining dependencies)"
    fi
done

# Delete Secrets Manager secrets
print_info "Checking for Secrets Manager secrets..."
SECRETS=$(aws secretsmanager list-secrets --region "$REGION" \
    --query 'SecretList[?contains(Name, `encryption-api`)].Name' --output text)

for SECRET in $SECRETS; do
    if [ -n "$SECRET" ]; then
        print_info "Deleting secret: $SECRET"
        aws secretsmanager delete-secret \
            --secret-id "$SECRET" \
            --force-delete-without-recovery \
            --region "$REGION" 2>/dev/null || \
            print_warning "Could not delete secret $SECRET"
    fi
done

###############################################################################
# Step 3: Verification
###############################################################################
print_header "Step 3: Verification"

print_info "Verifying cleanup..."

REMAINING_EIPS=$(aws ec2 describe-addresses --region "$REGION" --query 'Addresses | length(@)')
REMAINING_NAT=$(aws ec2 describe-nat-gateways --region "$REGION" \
    --filter "Name=state,Values=available" "Name=tag:Project,Values=encryption-api" \
    --query 'NatGateways | length(@)')
REMAINING_VPCS=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Project,Values=encryption-api" \
    --query 'Vpcs | length(@)')

echo "Elastic IPs (all): $REMAINING_EIPS"
echo "NAT Gateways (encryption-api): $REMAINING_NAT"
echo "VPCs (encryption-api): $REMAINING_VPCS"

if [ "$REMAINING_NAT" == "0" ] && [ "$REMAINING_VPCS" == "0" ]; then
    print_success "All encryption-api resources have been cleaned up!"
else
    print_warning "Some resources may still be deleting. Run this script again in a few minutes."
fi

print_header "Cleanup Complete"

print_info "To check for any remaining resources:"
echo "  aws ec2 describe-vpcs --region $REGION --filters 'Name=tag:Project,Values=encryption-api'"
echo "  aws ecs list-clusters --region $REGION"
echo "  aws rds describe-db-instances --region $REGION"
