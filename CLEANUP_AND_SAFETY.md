# AWS Resource Cleanup and Safety Guide

## Overview

This document explains the safety mechanisms added to prevent orphaned AWS resources that incur costs. Multiple deployment attempts or failures can create resources that remain active and charging if not properly cleaned up.

## The Problem

During our deployment testing, failed Terraform applies left orphaned resources:
- NAT Gateways (~$30/month each)
- Elastic IPs (~$3.60/month when not attached)
- VPCs with networking components
- RDS instances
- ECS clusters

**These resources continue to incur charges even after partial failures.**

## Safety Mechanisms Implemented

### 1. Safe Deployment Script (`scripts/safe-terraform-apply.sh`)

**Purpose**: Automatically rollback failed deployments to prevent orphaned resources.

**Features**:
- Pre-deployment validation
- Cost estimate warnings
- Automatic rollback on any failure
- Post-deployment verification
- User confirmation before applying changes

**Usage**:
```bash
./scripts/safe-terraform-apply.sh
```

**How it works**:
1. Validates Terraform configuration
2. Creates execution plan
3. Shows cost estimates and asks for confirmation
4. Applies changes
5. **If ANY error occurs**: Automatically runs `terraform destroy` to remove partially created resources
6. Verifies deployment success

**Error Handling**:
```bash
# Automatic rollback on failure using bash trap
trap cleanup_on_error EXIT

cleanup_on_error() {
    if [ $exit_code -ne 0 ]; then
        terraform destroy -auto-approve  # Removes all resources
    fi
}
```

### 2. Comprehensive Cleanup Script (`scripts/cleanup-aws.sh`)

**Purpose**: Remove ALL resources (terraform-managed and orphaned) in one command.

**Features**:
- Terraform destroy
- Orphaned resource cleanup
- ECR image deletion
- NAT Gateway cleanup with wait
- Elastic IP release
- VPC and networking cleanup
- Secrets Manager cleanup
- Verification report

**Usage**:
```bash
./scripts/cleanup-aws.sh [--region us-west-2]
```

**What it cleans**:
1. **Terraform Resources**: Runs `terraform destroy`
2. **Orphaned NAT Gateways**: Finds and deletes all NAT Gateways tagged with `Project=encryption-api`
3. **Orphaned Elastic IPs**: Releases all EIPs with project tag
4. **Orphaned VPCs**: Deletes VPCs and all dependencies
5. **Orphaned ECS Clusters**: Stops tasks, deletes services, deletes clusters
6. **Orphaned RDS Instances**: Deletes databases without snapshots
7. **Secrets Manager**: Removes encryption keys

**Safety Features**:
- Requires explicit "yes" confirmation
- Shows what will be deleted
- Waits for NAT Gateways to fully delete before releasing EIPs
- Handles dependencies in correct order
- Provides verification summary

### 3. Terraform Configuration Updates

**Changes to `terraform/main.tf`**:

```hcl
# Added lifecycle configuration
locals {
  resource_lifecycle = {
    prevent_destroy = false
    create_before_destroy = false
  }
}
```

This ensures Terraform allows resource destruction and doesn't try to create resources before destroying old ones (which can cause conflicts).

### 4. Updated `.gitignore`

Protected sensitive files from accidental commits:
```
# Terraform
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/terraform.tfvars

# Deployment artifacts
deployment-info.txt
```

## Cost Breakdown

**Monthly AWS Costs** (if resources are left running):

| Resource | Approximate Cost |
|----------|-----------------|
| RDS MySQL (db.t3.micro) | $15-20/month |
| ECS Fargate (1 task) | $5-10/month |
| NAT Gateway | $30-35/month |
| Elastic IP (attached) | Free |
| Elastic IP (unattached) | $3.60/month |
| Data Transfer | Variable |
| **TOTAL** | **$50-65/month** |

**Orphaned Resources from Failed Deployments**:
- Each orphaned NAT Gateway: $32/month
- Each unattached Elastic IP: $3.60/month
- VPCs and subnets: Free (but prevent proper cleanup)

## Best Practices

### 1. Always Use Safe Deployment Script

✅ **DO**:
```bash
./scripts/safe-terraform-apply.sh
```

❌ **DON'T**:
```bash
cd terraform
terraform apply -auto-approve  # No automatic rollback!
```

### 2. Clean Up Immediately After Testing

After testing your deployment:
```bash
./scripts/cleanup-aws.sh
```

**Don't wait** - resources charge by the hour.

### 3. Verify Cleanup

After running cleanup, verify everything is gone:
```bash
# Check Elastic IPs
aws ec2 describe-addresses --region us-west-2

# Check NAT Gateways
aws ec2 describe-nat-gateways --region us-west-2 \
  --filter "Name=state,Values=available"

# Check VPCs (should only see default VPCs)
aws ec2 describe-vpcs --region us-west-2 \
  --filters "Name=tag:Project,Values=encryption-api"
```

### 4. Monitor AWS Costs

- Enable AWS Cost Explorer
- Set up billing alerts for >$10/month
- Check the billing dashboard weekly

### 5. Handle ECR Images

ECR images prevent repository deletion. The cleanup script handles this:
```bash
# Cleanup script automatically:
# 1. Lists all images in ECR
# 2. Deletes all images
# 3. Deletes the repository
```

## Common Scenarios

### Scenario 1: Deployment Fails Mid-Way

**What Happens**:
```
Terraform creates:
✅ VPC
✅ Subnets
✅ NAT Gateway
✅ Elastic IP
❌ RDS fails (bad password)
```

**Without Safe Script**: NAT Gateway and EIP remain active, costing $32+/month

**With Safe Script**: Automatic rollback removes all created resources

### Scenario 2: Multiple Failed Attempts

**Problem**: Each failed attempt creates orphaned resources

**Solution**: Run cleanup script before retrying:
```bash
./scripts/cleanup-aws.sh
./scripts/safe-terraform-apply.sh
```

### Scenario 3: Forgot to Cleanup

**Realization**: "I deployed 2 weeks ago and forgot to destroy!"

**Solution**:
```bash
# First try Terraform destroy
cd terraform
terraform destroy -auto-approve

# Then cleanup any orphaned resources
cd ..
./scripts/cleanup-aws.sh

# Verify in AWS console that everything is gone
```

**Cost**: ~$100-130 (2 weeks * $50-65/month)

## Troubleshooting

### Cleanup Script Fails

If cleanup script encounters errors:

1. **Check Terraform state**:
```bash
cd terraform
terraform destroy -auto-approve
```

2. **Manually check for resources**:
```bash
# NAT Gateways
aws ec2 describe-nat-gateways --region us-west-2

# ECS Clusters
aws ecs list-clusters --region us-west-2

# RDS Instances
aws rds describe-db-instances --region us-west-2
```

3. **Force delete specific resources**:
```bash
# Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id nat-xxxxx --region us-west-2

# Wait for deletion (takes 2-3 minutes)
# Then release EIP
aws ec2 release-address --allocation-id eipalloc-xxxxx --region us-west-2
```

### VPC Won't Delete

**Error**: "VPC has dependencies and cannot be deleted"

**Solution**: Delete in this order:
1. NAT Gateways
2. Internet Gateways (detach first)
3. Subnets
4. Route Tables (except main)
5. Security Groups (except default)
6. VPC

The cleanup script handles this order automatically.

### Terraform State Out of Sync

**Problem**: Resources exist in AWS but not in Terraform state

**Solution**:
```bash
# Skip Terraform, use cleanup script to find and delete by tags
./scripts/cleanup-aws.sh
```

## Files Reference

| File | Purpose |
|------|---------|
| `scripts/safe-terraform-apply.sh` | Deploy with automatic rollback |
| `scripts/cleanup-aws.sh` | Delete all resources |
| `terraform/main.tf` | Updated with lifecycle rules |
| `README.md` | Updated with cost warnings |
| `.gitignore` | Protects sensitive files |

## Quick Commands

```bash
# Safe deployment
./scripts/safe-terraform-apply.sh

# Complete cleanup
./scripts/cleanup-aws.sh

# Verify cleanup
aws ec2 describe-addresses --region us-west-2
aws ec2 describe-nat-gateways --region us-west-2 --filter "Name=state,Values=available"

# Check costs
aws ce get-cost-and-usage --time-period Start=2025-11-01,End=2025-11-21 \
  --granularity MONTHLY --metrics UnblendedCost
```

## Emergency Cleanup

If you need to delete EVERYTHING immediately:

```bash
# Run cleanup script
./scripts/cleanup-aws.sh

# Manually verify and delete in AWS Console:
# 1. Go to VPC Dashboard
# 2. Check NAT Gateways - delete any found
# 3. Check Elastic IPs - release any found
# 4. Go to RDS - delete any databases
# 5. Go to ECS - delete clusters
# 6. Go to ECR - delete repositories
```

## Summary

**Key Takeaways**:
1. ✅ Always use `./scripts/safe-terraform-apply.sh` for deployments
2. ✅ Always run `./scripts/cleanup-aws.sh` after testing
3. ✅ Verify cleanup completed successfully
4. ✅ Monitor AWS billing regularly
5. ❌ Never leave resources running overnight unless actively using them

**Cost Protection**:
- Automatic rollback on failure
- Comprehensive cleanup script
- Clear documentation and warnings
- Verification steps

This prevents the costly mistakes that occurred during initial testing where failed deployments left expensive resources running.
