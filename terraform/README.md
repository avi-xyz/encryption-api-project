# Terraform AWS Deployment Guide

## Overview
This Terraform configuration deploys the Encryption API to AWS with:
- **ECS Fargate**: Serverless container orchestration
- **RDS MySQL 8**: Managed database (Multi-AZ in production)
- **Application Load Balancer**: HTTPS endpoint with health checks
- **Secrets Manager**: Secure storage for encryption keys
- **VPC**: Custom networking with public/private subnets
- **CloudWatch**: Centralized logging and monitoring

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** >= 1.0 installed
   ```bash
   brew install terraform
   ```
4. **Docker image** pushed to ECR (done by CI/CD pipeline)

## Initial Setup

### 1. Configure Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `db_password`: Strong database password
- `master_encryption_key`: Generate with `openssl rand -base64 32`
- Other variables as needed

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Review Planned Changes
```bash
terraform plan
```

### 4. Deploy Infrastructure
```bash
terraform apply
```

This will create:
- VPC with subnets across 2 availability zones
- RDS MySQL database
- ECS cluster and service
- Application Load Balancer
- IAM roles and security groups
- CloudWatch log groups
- Secrets Manager entries

Deployment takes approximately 10-15 minutes.

## Post-Deployment

### 1. Push Docker Image to ECR
```bash
# Get ECR repository URL from Terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Build and push image
cd ..
docker build -t encryption-api .
docker tag encryption-api:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

### 2. Update ECS Service
After pushing a new image, force ECS to redeploy:
```bash
aws ecs update-service \
  --cluster encryption-api-cluster \
  --service encryption-api-service \
  --force-new-deployment \
  --region us-east-1
```

### 3. Get Application URL
```bash
terraform output alb_url
```

### 4. Test the API
```bash
ALB_URL=$(terraform output -raw alb_url)

# Health check
curl $ALB_URL/api/health

# Encrypt data
curl -X POST $ALB_URL/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from AWS!"}'
```

## Monitoring

### View Logs
```bash
# Get log group name
LOG_GROUP=$(terraform output -raw cloudwatch_log_group)

# Tail logs
aws logs tail $LOG_GROUP --follow --region us-east-1
```

### View ECS Service Status
```bash
aws ecs describe-services \
  --cluster encryption-api-cluster \
  --services encryption-api-service \
  --region us-east-1
```

## Scaling

### Horizontal Scaling (More Tasks)
```bash
# Update desired count in terraform.tfvars
ecs_desired_count = 4

# Apply changes
terraform apply
```

### Vertical Scaling (More CPU/Memory)
```bash
# Update in terraform.tfvars
ecs_task_cpu    = "1024"  # 1 vCPU
ecs_task_memory = "2048"  # 2 GB

# Apply changes
terraform apply
```

## Cost Optimization

### Development Environment
- Use `db.t3.micro` for RDS (free tier eligible)
- Set `ecs_desired_count = 1`
- Set `multi_az = false` for RDS

### Production Environment
- Use `db.t3.small` or larger for RDS
- Set `ecs_desired_count = 2` or more
- Enable Multi-AZ for RDS
- Enable deletion protection for ALB

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will delete all data including the database!

## Troubleshooting

### ECS Task Fails to Start
1. Check CloudWatch logs:
   ```bash
   aws logs tail /ecs/encryption-api --follow
   ```
2. Verify database connectivity
3. Check Secrets Manager values

### Database Connection Issues
1. Verify security group allows traffic from ECS
2. Check database credentials in Secrets Manager
3. Ensure RDS is in available state

### Load Balancer Health Checks Failing
1. Verify `/api/health` endpoint is accessible
2. Check ECS task is running
3. Review target group health status

## Security Best Practices

1. **Never commit** `terraform.tfvars` to version control
2. **Rotate credentials** regularly
3. **Enable SSL/TLS** on Load Balancer (requires ACM certificate)
4. **Restrict security groups** to minimum required access
5. **Enable CloudTrail** for audit logging
6. **Use IAM roles** instead of access keys where possible

## Production Checklist

- [ ] Enable Multi-AZ for RDS
- [ ] Configure automated backups
- [ ] Set up SSL certificate in ACM
- [ ] Configure ALB HTTPS listener
- [ ] Enable deletion protection on critical resources
- [ ] Set up CloudWatch alarms
- [ ] Configure auto-scaling policies
- [ ] Enable RDS encryption
- [ ] Review and restrict security groups
- [ ] Set up VPC flow logs
- [ ] Configure WAF rules (optional)
- [ ] Set up disaster recovery plan
