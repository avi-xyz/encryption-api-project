# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in this project, please email security@yourcompany.com with:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

Please do NOT create a public GitHub issue for security vulnerabilities.

## Secure Configuration

### Never Commit Sensitive Data

The following files contain sensitive information and must NEVER be committed to git:

- `terraform/terraform.tfvars` - Contains actual passwords and encryption keys
- `terraform/*.tfstate*` - May contain sensitive infrastructure data
- `*.BACKUP_DO_NOT_COMMIT` - Backup files with real credentials
- Any file containing actual API Gateway URLs, Cognito Pool IDs, or Client IDs

### Using Example Files

This repository includes example configuration files:

1. **terraform/terraform.tfvars.example** - Copy to `terraform/terraform.tfvars` and fill in your actual values
2. **scripts/provision-api-user.sh** - Set `COGNITO_USER_POOL_ID` environment variable

### Generating Secure Credentials

Always use cryptographically secure random values:

```bash
# Generate database password
openssl rand -base64 24

# Generate master encryption key
openssl rand -base64 32
```

### Environment Variables

For local development and production deployments, use environment variables instead of hardcoded values:

```bash
export COGNITO_USER_POOL_ID="your-actual-pool-id"
export COGNITO_CLIENT_ID="your-actual-client-id"
export DB_PASSWORD="your-secure-password"
export ENCRYPTION_MASTER_KEY="your-base64-encoded-key"
```

## Security Best Practices

1. **Rotate Credentials Regularly**
   - Database passwords: Every 90 days
   - Encryption keys: Annually (with proper key rotation strategy)
   - API tokens: Every 30 days

2. **Use AWS Secrets Manager**
   - Store all production secrets in AWS Secrets Manager
   - Never hardcode secrets in code or configuration files

3. **Enable MFA**
   - Enable Multi-Factor Authentication for all AWS accounts
   - Require MFA for Cognito user pool (optional but recommended)

4. **Monitor Access**
   - Enable CloudTrail for audit logging
   - Monitor CloudWatch logs for suspicious activity
   - Set up alerts for authentication failures

5. **Least Privilege**
   - Use IAM roles with minimum required permissions
   - Regularly audit and remove unnecessary permissions

## Dependency Security

Run security audits regularly:

```bash
# Maven dependency check
./mvnw dependency-check:check

# Check for outdated dependencies
./mvnw versions:display-dependency-updates
```

## Disclosure Policy

We follow responsible disclosure principles:

1. Report received and acknowledged within 24 hours
2. Investigation and fix development within 7 days
3. Security patch released within 14 days
4. Public disclosure 30 days after patch release

Thank you for helping keep this project secure!
