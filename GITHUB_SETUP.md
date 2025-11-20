# GitHub Repository Setup Guide

This guide walks you through creating a new GitHub repository and pushing this project to it.

## Prerequisites

- GitHub account (sign up at https://github.com)
- Git installed and configured
- GitHub CLI (optional, but recommended)

## Option 1: Using GitHub CLI (Recommended)

### 1. Install GitHub CLI
```bash
brew install gh
```

### 2. Authenticate with GitHub
```bash
gh auth login
```

Follow the prompts to authenticate.

### 3. Create Repository and Push
```bash
cd /Users/avinash/encryption-api-project

# Initialize git if not already done
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Encryption API with Spring Boot, Docker, and AWS deployment"

# Create GitHub repository and push
gh repo create avi-xyz/encryption-api \
  --public \
  --source=. \
  --remote=origin \
  --push

# Set up branch protection (optional)
gh api repos/avi-xyz/encryption-api/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["test"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"dismiss_stale_reviews":true}'
```

## Option 2: Using GitHub Web Interface

### 1. Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `encryption-api`
3. Owner: `avi-xyz`
4. Description: "Production-ready REST API for AES-256-GCM encryption with MySQL storage"
5. Select **Public** or **Private**
6. Do NOT initialize with README, .gitignore, or license
7. Click **Create repository**

### 2. Push Local Project to GitHub

```bash
cd /Users/avinash/encryption-api-project

# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Encryption API with Spring Boot, Docker, and AWS deployment"

# Add remote repository
git remote add origin https://github.com/avi-xyz/encryption-api.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Configure GitHub Secrets for CI/CD

After pushing the code, configure secrets for the GitHub Actions pipeline:

### 1. Navigate to Repository Settings
```
https://github.com/avi-xyz/encryption-api/settings/secrets/actions
```

### 2. Add Required Secrets

Click **New repository secret** for each:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | From AWS IAM user |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | From AWS IAM user |
| `AWS_REGION` | `us-east-1` | AWS region |
| `ECR_REPOSITORY` | `encryption-api` | ECR repository name |
| `ECS_CLUSTER` | `encryption-api-cluster` | ECS cluster name |
| `ECS_SERVICE` | `encryption-api-service` | ECS service name |

### 3. Get AWS Credentials

If you don't have AWS credentials yet:

```bash
# Create IAM user with programmatic access
aws iam create-user --user-name github-actions

# Attach policies
aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

# Create access key
aws iam create-access-key --user-name github-actions
```

Save the `AccessKeyId` and `SecretAccessKey` from the output.

## Verify CI/CD Pipeline

### 1. Check Workflow Status

After pushing, check the Actions tab:
```
https://github.com/avi-xyz/encryption-api/actions
```

### 2. Test the Pipeline

Make a small change and push:
```bash
echo "# Test" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push
```

The pipeline should:
- ✅ Run tests
- ✅ Build JAR
- ✅ Build Docker image (on main branch)
- ✅ Push to ECR (on main branch)
- ✅ Deploy to ECS (on main branch)

## Repository Settings Recommendations

### Branch Protection

1. Go to Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Include administrators

### Enable Dependabot

1. Go to Settings → Security → Dependabot
2. Enable:
   - ✅ Dependabot alerts
   - ✅ Dependabot security updates
   - ✅ Dependabot version updates

Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "maven"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Add Topics

Add relevant topics to help others find your repository:
```
Settings → General → Topics
```

Suggested topics:
- `spring-boot`
- `java`
- `encryption`
- `aes-256-gcm`
- `rest-api`
- `docker`
- `aws`
- `terraform`
- `mysql`

## Clone the Repository

Now anyone can clone your repository:

```bash
git clone https://github.com/avi-xyz/encryption-api.git
cd encryption-api
./scripts/setup-mac.sh
```

## Useful Git Commands

### Update from Remote
```bash
git pull origin main
```

### Create Feature Branch
```bash
git checkout -b feature/my-feature
git push -u origin feature/my-feature
```

### Create Pull Request
```bash
gh pr create --title "Add new feature" --body "Description of changes"
```

### View Repository
```bash
gh repo view --web
```

## Troubleshooting

### Authentication Failed
If you get authentication errors:
```bash
# Use Personal Access Token
gh auth login

# Or configure Git credentials
git config --global credential.helper osxkeychain
```

### Large File Error
If you accidentally committed large files:
```bash
# Install git-lfs
brew install git-lfs
git lfs install

# Track large files
git lfs track "*.jar"
git add .gitattributes
```

### Force Push (Use Carefully!)
Only if absolutely necessary:
```bash
git push --force origin main
```

## Next Steps

1. ✅ Repository created and pushed
2. ✅ CI/CD secrets configured
3. ✅ Branch protection enabled
4. Configure AWS infrastructure (see terraform/README.md)
5. Test the complete deployment pipeline
6. Share repository with team members

## Additional Resources

- [GitHub Docs](https://docs.github.com)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Git Basics](https://git-scm.com/book/en/v2/Getting-Started-Git-Basics)
