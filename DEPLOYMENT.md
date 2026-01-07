# AWS Deployment Guide

## Automated Deployment (Recommended)

Deploy to AWS with a single command:

```bash
./scripts/deploy-to-aws.sh
```

The script will:
1. ✅ Check prerequisites (AWS CLI, Terraform, Docker)
2. ✅ Configure AWS credentials (if needed)
3. ✅ Prompt for deployment configuration
4. ✅ Generate encryption keys automatically
5. ✅ Create Terraform configuration
6. ✅ Deploy infrastructure to AWS
7. ✅ Build and push Docker image
8. ✅ Deploy to ECS
9. ✅ Test the deployment
10. ✅ Provide you with the application URL

**Time:** ~15-20 minutes
**Cost:** ~$20-30/month for development

### What You'll Need

1. **AWS Account**
   - Sign up at https://aws.amazon.com
   - Create IAM user with admin access
   - Get Access Key ID and Secret Access Key

2. **Required Information** (script will prompt):
   - AWS Region (default: us-east-1)
   - Environment name (development/staging/production)
   - Database password (strong password)
   - ECS configuration (CPU, memory, task count)

## Manual Deployment

If you prefer manual control, see [terraform/README.md](terraform/README.md)

## Post-Deployment

### Access Your API

After deployment, you'll get an Application Load Balancer URL:

```bash
# Health check
curl http://your-alb-url.amazonaws.com/api/health

# Encrypt data
curl -X POST http://your-alb-url.amazonaws.com/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello from AWS!"}'

# Decrypt data
curl http://your-alb-url.amazonaws.com/api/decrypt/1
```

### Monitor Your Application

```bash
# View logs
aws logs tail /ecs/encryption-api --follow --region us-east-1

# Check service status
aws ecs describe-services \
  --cluster encryption-api-cluster \
  --services encryption-api-service \
  --region us-east-1
```

### Update Your Application

After making code changes:

```bash
# Re-run the deployment script
./scripts/deploy-to-aws.sh

# Or manually:
cd terraform
ECR_URL=$(terraform output -raw ecr_repository_url)
cd ..
docker build -t encryption-api .
docker tag encryption-api:latest $ECR_URL:latest
docker push $ECR_URL:latest
aws ecs update-service \
  --cluster encryption-api-cluster \
  --service encryption-api-service \
  --force-new-deployment \
  --region us-east-1
```

## Cleanup

To delete all AWS resources and stop incurring charges:

```bash
cd terraform
terraform destroy
```

**⚠️ Warning:** This deletes EVERYTHING including your database and all encrypted data!

## Cost Breakdown

### Development Environment
- **ECS Fargate**: ~$10-15/month (1 task)
- **RDS MySQL**: ~$10-15/month (db.t3.micro)
- **Load Balancer**: ~$16/month
- **Data Transfer**: ~$1-2/month
- **Total**: ~$20-30/month

### Production Environment
- **ECS Fargate**: ~$30-50/month (2-4 tasks)
- **RDS MySQL**: ~$30-60/month (db.t3.small, Multi-AZ)
- **Load Balancer**: ~$16/month
- **Data Transfer**: ~$5-10/month
- **Total**: ~$50-100/month

## Troubleshooting

### Deployment Script Fails

**Check prerequisites:**
```bash
aws --version      # Should show AWS CLI version
terraform --version # Should show Terraform version
docker --version   # Should show Docker version
docker info        # Should not error
```

**Check AWS credentials:**
```bash
aws sts get-caller-identity
```

### Health Checks Failing

```bash
# View ECS service events
aws ecs describe-services \
  --cluster encryption-api-cluster \
  --services encryption-api-service \
  --region us-east-1 \
  --query 'services[0].events' \
  --output table

# View application logs
aws logs tail /ecs/encryption-api --follow --region us-east-1
```

### Database Connection Issues

1. Check security groups allow traffic from ECS to RDS
2. Verify database credentials in Secrets Manager
3. Ensure RDS is in "available" state

## Security Best Practices

- ✅ **Never commit** `terraform.tfvars` or `deployment-info.txt`
- ✅ **Rotate credentials** every 90 days
- ✅ **Enable MFA** on your AWS account
- ✅ **Use SSL/TLS** in production (requires ACM certificate)
- ✅ **Enable CloudTrail** for audit logging
- ✅ **Review security groups** regularly
- ✅ **Enable RDS encryption** for production
- ✅ **Set up automated backups**

## Production Checklist

Before going to production:

- [ ] Enable Multi-AZ for RDS
- [ ] Configure automated backups (retention: 7-30 days)
- [ ] Set up SSL certificate in AWS Certificate Manager
- [ ] Configure HTTPS listener on ALB
- [ ] Enable deletion protection on ALB and RDS
- [ ] Set up CloudWatch alarms (CPU, memory, errors)
- [ ] Configure auto-scaling policies
- [ ] Enable RDS encryption at rest
- [ ] Review and tighten security groups
- [ ] Set up VPC flow logs
- [ ] Configure WAF rules (optional)
- [ ] Document disaster recovery plan
- [ ] Set up monitoring dashboard
- [ ] Configure alerting (PagerDuty, Slack, etc.)

## Support

For issues or questions:
1. Check the logs: `aws logs tail /ecs/encryption-api --follow`
2. Review Terraform state: `cd terraform && terraform show`
3. Check AWS Console for resource status
4. Review [terraform/README.md](terraform/README.md) for detailed documentation
