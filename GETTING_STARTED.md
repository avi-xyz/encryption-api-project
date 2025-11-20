# 🚀 Getting Started with Encryption API

Welcome! This guide will get you up and running in minutes.

## 🎯 What You're Getting

A complete, production-ready REST API that:
- Encrypts strings using military-grade AES-256-GCM encryption
- Stores encrypted data securely in MySQL 8
- Runs in Docker containers
- Deploys to AWS with one command
- Includes full CI/CD automation
- Has comprehensive tests

## ⚡ Quick Start (5 Minutes)

### Step 1: Run the Automated Setup
```bash
cd ~/encryption-api-project
./scripts/setup-mac.sh
```

This script installs everything you need:
- ✅ Java 17
- ✅ Maven
- ✅ Docker Desktop
- ✅ VS Code with Java extensions
- ✅ Terraform
- ✅ AWS CLI
- ✅ Builds and tests the project
- ✅ Starts MySQL database

**Estimated time**: 5-10 minutes (depending on download speeds)

### Step 2: Start the Application
```bash
# The setup script already started MySQL, so just run:
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

### Step 3: Test the API
```bash
# In a new terminal window:

# Health check
curl http://localhost:8080/api/health

# Encrypt some data
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"My secret message!"}'
```

You should see:
```json
{
  "id": 1,
  "message": "Data encrypted and stored successfully",
  "timestamp": "2025-11-19T10:30:00"
}
```

**🎉 Congratulations! Your encryption API is running!**

## 📖 What's Next?

### Option A: Just Want to Use It Locally?
You're done! Keep using the API with the curl commands above.

### Option B: Want to Develop and Modify?
```bash
# Open in VS Code
code .

# Press F5 to start debugging
# Make changes and they'll hot-reload
```

### Option C: Want to Deploy to AWS?
Follow the [AWS Deployment Guide](terraform/README.md):
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

### Option D: Want to Set Up GitHub Repository?
Follow the [GitHub Setup Guide](GITHUB_SETUP.md):
```bash
gh repo create avi-xyz/encryption-api --public --source=. --push
```

## 📚 Documentation Map

Not sure which document to read? Here's what each one covers:

### Start Here
- **[GETTING_STARTED.md](GETTING_STARTED.md)** ← You are here!
- **[README.md](README.md)** - Complete user guide and API reference
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - What's been built and project stats

### Development
- **[SETUP.md](SETUP.md)** - Manual installation steps
- **[PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md)** - Technical architecture and design

### Deployment
- **[terraform/README.md](terraform/README.md)** - AWS deployment guide
- **[GITHUB_SETUP.md](GITHUB_SETUP.md)** - GitHub repository setup

## 🔍 Common Questions

### Where is the project located?
```bash
/Users/avinash/encryption-api-project/
```

### How do I stop the application?
Press `Ctrl+C` in the terminal where it's running.

### How do I stop MySQL?
```bash
docker-compose down
```

### How do I restart everything?
```bash
docker-compose down
docker-compose up -d
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

### How do I run tests?
```bash
./mvnw verify
```

### How do I rebuild the project?
```bash
./mvnw clean package
```

### Where are the logs?
```bash
# Application logs - in the terminal
# Docker logs
docker-compose logs -f
```

### How do I check if everything is working?
```bash
# Check Java
java -version  # Should show 17.x.x

# Check Docker
docker ps  # Should show MySQL running

# Check application
curl http://localhost:8080/api/health  # Should return {"status":"UP"}
```

## 🛠️ Useful Commands Cheat Sheet

### Application
```bash
# Start application
./mvnw spring-boot:run -Dspring-boot.run.profiles=local

# Run tests
./mvnw test

# Run all tests including integration
./mvnw verify

# Build JAR
./mvnw clean package

# Clean build
./mvnw clean
```

### Docker
```bash
# Start all services
docker-compose up

# Start in background
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# Rebuild containers
docker-compose up --build
```

### Git (After GitHub Setup)
```bash
# Check status
git status

# Commit changes
git add .
git commit -m "Your message"

# Push to GitHub
git push

# Pull latest changes
git pull
```

### AWS (After Deployment)
```bash
# View infrastructure
terraform output

# Check ECS service
aws ecs describe-services --cluster encryption-api-cluster --services encryption-api-service

# View logs
aws logs tail /ecs/encryption-api --follow
```

## 🎓 Understanding the Code

### Key Files to Explore

1. **[EncryptionService.java](src/main/java/com/aviencryption/service/EncryptionService.java)**
   - Core encryption logic
   - AES-256-GCM implementation
   - Key management

2. **[EncryptionController.java](src/main/java/com/aviencryption/controller/EncryptionController.java)**
   - REST API endpoints
   - Request/response handling

3. **[EncryptedData.java](src/main/java/com/aviencryption/model/EncryptedData.java)**
   - Database entity
   - How data is stored

4. **[docker-compose.yml](docker-compose.yml)**
   - Local development setup
   - MySQL configuration

5. **[terraform/main.tf](terraform/main.tf)**
   - AWS infrastructure
   - ECS, RDS, VPC setup

## 🔒 Security Note

The default encryption key in `application-local.yml` is for **development only**.

For production:
1. Generate a secure key: `openssl rand -base64 32`
2. Store in AWS Secrets Manager
3. Never commit keys to Git

## 🆘 Need Help?

1. **Read the error message** - Most errors are self-explanatory
2. **Check [README.md](README.md#troubleshooting)** - Troubleshooting section
3. **Review logs** - `docker-compose logs -f`
4. **Verify prerequisites** - Java 17, Docker running, etc.

## 🎯 What to Do Now

Choose your path:

### Path 1: Explorer 🔍
```bash
code .  # Open in VS Code and explore the code
```

### Path 2: Tester 🧪
```bash
./mvnw verify  # Run all tests and see them pass
```

### Path 3: Developer 💻
```bash
# Make a change to EncryptionController.java
# Add a new endpoint
# Test it with curl
```

### Path 4: DevOps Engineer 🚀
```bash
cd terraform
terraform init
# Deploy to AWS
```

### Path 5: Learner 📚
Read [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) to understand the design

---

## 🌟 Quick Reference

| I want to... | Command |
|--------------|---------|
| Start the app | `./mvnw spring-boot:run -Dspring-boot.run.profiles=local` |
| Run tests | `./mvnw verify` |
| Start MySQL | `docker-compose up -d mysql` |
| Stop everything | `docker-compose down` + `Ctrl+C` |
| Open in VS Code | `code .` |
| Encrypt data | `curl -X POST http://localhost:8080/api/encrypt -H "Content-Type: application/json" -d '{"plainText":"test"}'` |
| Check health | `curl http://localhost:8080/api/health` |

## 📞 Support

- **Documentation**: All .md files in this project
- **Code Comments**: Extensive inline documentation
- **GitHub Issues**: (After creating repo) Create an issue

---

**Welcome aboard! Happy coding! 🚀**

*This project is designed to be production-ready from day one. Every component has been carefully architected, tested, and documented.*
