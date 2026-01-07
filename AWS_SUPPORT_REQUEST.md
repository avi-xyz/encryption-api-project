# AWS Support Request: Enable Application Load Balancer Creation

## Issue Summary
My AWS account (ID: YOUR-AWS-ACCOUNT-ID) is currently unable to create Application Load Balancers (ALBs) in any region. I receive the following error when attempting to create an ALB:

```
OperationNotPermitted: This AWS account currently does not support creating load balancers.
For more information, please contact AWS Support.
```

## Request
I would like to request that the restriction on creating Application Load Balancers be lifted for my AWS account.

## Use Case
I am developing a containerized REST API application (Encryption API) deployed on Amazon ECS Fargate with an RDS MySQL database. I need an Application Load Balancer to:

1. Provide a stable endpoint for my API (instead of changing ECS task public IPs)
2. Enable SSL/TLS termination for secure HTTPS connections
3. Implement health checks and automatic routing to healthy ECS tasks
4. Support future scaling with multiple ECS tasks behind the load balancer

## Account Information
- **Account ID**: YOUR-AWS-ACCOUNT-ID
- **Primary Region**: us-west-2 (US West - Oregon)
- **Error Reproduced In**: us-west-2, us-east-1

## Steps Taken
1. Verified account has quota of 50 Application Load Balancers per region
2. Confirmed IAM permissions allow ELB actions
3. Attempted ALB creation via AWS CLI in multiple regions
4. All attempts result in the "OperationNotPermitted" error

## Technical Details
- **Service**: Elastic Load Balancing v2 (Application Load Balancers)
- **API Call**: `CreateLoadBalancer`
- **Error Code**: OperationNotPermitted
- **Attempted Command**:
  ```bash
  aws elbv2 create-load-balancer \
    --name my-application-lb \
    --subnets subnet-xxxxx subnet-yyyyy \
    --region us-west-2 \
    --type application
  ```

## Current Workaround
I am currently using ECS tasks with public IP addresses as a temporary workaround, but this is not suitable for production use due to:
- IP addresses change when tasks restart
- No built-in SSL/TLS termination
- Manual health check management
- Difficulty with DNS configuration

## Request Priority
Medium - This is blocking my ability to properly deploy my application for production use, though I have a temporary workaround for development/testing.

## Additional Information
- I am willing to provide any additional information or verification needed
- My account is in good standing with no outstanding billing issues
- I understand there may be account verification requirements

Thank you for your assistance in resolving this issue.

---

**How to Submit This Request:**

1. Go to: https://console.aws.amazon.com/support/home#/case/create
2. Select: "Account and billing support" or "Service limit increase"
3. Category: "Elastic Load Balancing"
4. Subject: "Enable Application Load Balancer Creation for Account"
5. Copy and paste the content above into the description
6. Submit the case

**Expected Response Time:**
- Business Support: Within 12 hours
- Developer Support: Within 12-24 hours
- Basic Support: May require upgrading support plan
