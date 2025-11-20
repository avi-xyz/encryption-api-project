# Encryption API

A production-ready REST API for encrypting strings using AES-256-GCM encryption and storing them securely in MySQL 8. Built with Spring Boot, containerized with Docker, and deployable to AWS ECS with full CI/CD automation.

## Features

- **Strong Encryption**: AES-256-GCM (Galois/Counter Mode) - industry standard authenticated encryption
- **Secure Storage**: MySQL 8 database with encrypted data and key management
- **REST API**: Clean RESTful interface with JSON
- **Containerized**: Docker and Docker Compose for consistent environments
- **Cloud-Ready**: AWS ECS Fargate deployment with Terraform
- **CI/CD**: GitHub Actions pipeline with automated testing and deployment
- **Comprehensive Testing**: Unit tests, integration tests with Testcontainers
- **Automated Setup**: One-command macOS development environment setup

## Quick Start (macOS)

Clone and run the automated setup script:

```bash
git clone https://github.com/avi-xyz/encryption-api.git
cd encryption-api
./scripts/setup-mac.sh
```

This script will:
- Install all dependencies (Java 17, Maven, Docker, VS Code, etc.)
- Configure VS Code with Java extensions
- Build and test the project
- Start MySQL in Docker
- Set up the complete development environment

**Manual Setup**: See [SETUP.md](SETUP.md) for manual installation steps.

## Usage

### Start the Application

**Option 1: Using Docker Compose (Recommended)**
```bash
docker-compose up
```
The API will be available at `http://localhost:8080`

**Option 2: Run Locally (MySQL in Docker)**
```bash
# Start MySQL
docker-compose up -d mysql

# Run application
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

### API Endpoints

#### Encrypt Data
```bash
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"my secret message"}'
```

**Response:**
```json
{
  "id": 1,
  "message": "Data encrypted and stored successfully",
  "timestamp": "2025-11-19T10:30:00"
}
```

#### Decrypt Data (Optional)
```bash
curl http://localhost:8080/api/decrypt/1
```

**Response:**
```json
{
  "id": 1,
  "plainText": "my secret message",
  "timestamp": "2025-11-19T10:30:00"
}
```

#### Health Check
```bash
curl http://localhost:8080/api/health
```

**Response:**
```json
{
  "status": "UP",
  "timestamp": "2025-11-19T10:30:00"
}
```

## Testing

### Run All Tests
```bash
./mvnw verify
```

### Run Unit Tests Only
```bash
./mvnw test
```

### Run Integration Tests Only
```bash
./mvnw verify -DskipUnitTests
```

**Note**: Integration tests use Testcontainers to spin up a real MySQL instance automatically. No manual setup required!

## Development

### Project Structure
```
encryption-api-project/
├── src/
│   ├── main/java/com/aviencryption/
│   │   ├── controller/         # REST endpoints
│   │   ├── service/            # Business logic & encryption
│   │   ├── repository/         # Database access
│   │   ├── model/              # JPA entities
│   │   └── config/             # Configuration
│   └── test/                   # Unit & integration tests
├── terraform/                  # AWS infrastructure as code
├── .github/workflows/          # CI/CD pipeline
├── scripts/                    # Setup and utility scripts
└── docker-compose.yml         # Local development environment
```

### VS Code Setup

After running `setup-mac.sh`, open the project in VS Code:

```bash
code .
```

**Installed Extensions:**
- Java Extension Pack
- Spring Boot Tools
- Docker
- GitLens
- YAML support

**Available Tasks** (Cmd+Shift+B):
- Build project
- Run tests
- Start application
- Docker up/down

**Debug Configuration:**
- Press F5 to start debugging
- Breakpoints work in all Java files

### Environment Configuration

The application supports multiple profiles:

**Local Development** (`application-local.yml`):
- MySQL on localhost:3306
- Debug logging enabled
- Test encryption key

**Production** (`application-prod.yml`):
- AWS RDS MySQL
- Minimal logging
- Master key from AWS Secrets Manager

Set profile with:
```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

## Deployment to AWS

### Prerequisites
- AWS account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform installed

### Deploy Infrastructure

```bash
cd terraform

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# - Set db_password
# - Set master_encryption_key (generate with: openssl rand -base64 32)

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Deploy
terraform apply
```

### Deploy Application

After infrastructure is created:

```bash
# Get ECR repository URL
ECR_URL=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Build and push
docker build -t encryption-api .
docker tag encryption-api:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Update ECS service
aws ecs update-service \
  --cluster encryption-api-cluster \
  --service encryption-api-service \
  --force-new-deployment
```

**Or use GitHub Actions**: Push to `main` branch to automatically build, test, and deploy.

See [terraform/README.md](terraform/README.md) for detailed deployment documentation.

## CI/CD Pipeline

GitHub Actions automatically:
1. Runs all tests on every push/PR
2. Builds Docker image
3. Scans for security vulnerabilities
4. Pushes to AWS ECR
5. Deploys to ECS Fargate
6. Runs smoke tests

### Required GitHub Secrets
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `ECR_REPOSITORY`
- `ECS_CLUSTER`
- `ECS_SERVICE`

## Security

### Encryption Details
- **Algorithm**: AES-256-GCM
- **Key Size**: 256 bits (maximum AES key size)
- **IV**: 96 bits, randomly generated per encryption
- **Authentication**: 128-bit GCM tag prevents tampering
- **Key Management**: Each record uses a unique key, encrypted with master key

### Best Practices Implemented
- ✅ Non-root container user
- ✅ Secrets stored in AWS Secrets Manager
- ✅ TLS/SSL for database connections (production)
- ✅ Multi-AZ database deployment (production)
- ✅ VPC with private subnets
- ✅ Security groups with least privilege
- ✅ Encrypted database storage
- ✅ Container image vulnerability scanning
- ✅ Comprehensive logging to CloudWatch

### Security Considerations
- Master encryption key should be rotated regularly
- Use AWS Secrets Manager for all production secrets
- Enable AWS CloudTrail for audit logging
- Implement API authentication (e.g., OAuth 2.0, JWT)
- Add rate limiting for production
- Use HTTPS with valid SSL certificate

## Architecture

### Encryption Flow
1. Client sends plaintext via POST /api/encrypt
2. Service generates unique 256-bit AES key
3. Service generates random 96-bit IV
4. Plaintext encrypted with AES-256-GCM
5. Encryption key encrypted with master key
6. Ciphertext, encrypted key, and IV stored in MySQL
7. Record ID returned to client

### AWS Architecture
- **Compute**: ECS Fargate (serverless containers)
- **Database**: RDS MySQL 8 (Multi-AZ)
- **Load Balancer**: Application Load Balancer
- **Secrets**: AWS Secrets Manager
- **Logs**: CloudWatch Logs
- **Registry**: ECR (container images)

See [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) for detailed architecture documentation.

## Technology Stack

- **Java 17** - LTS with modern features
- **Spring Boot 3.2** - Application framework
- **Spring Data JPA** - Database access
- **MySQL 8** - Relational database
- **Docker** - Containerization
- **Terraform** - Infrastructure as Code
- **GitHub Actions** - CI/CD
- **AWS ECS Fargate** - Container orchestration
- **Testcontainers** - Integration testing

## Troubleshooting

### Application won't start
- Ensure MySQL is running: `docker-compose ps`
- Check logs: `docker-compose logs app`
- Verify database connection in `application-local.yml`

### Tests failing
- Ensure Docker is running (required for Testcontainers)
- Clean build: `./mvnw clean verify`
- Check Docker disk space: `docker system df`

### Docker Compose issues
- Stop all containers: `docker-compose down -v`
- Remove volumes: `docker volume prune`
- Restart: `docker-compose up`

### AWS Deployment issues
- Check CloudWatch logs: `aws logs tail /ecs/encryption-api --follow`
- Verify ECS service: `aws ecs describe-services --cluster encryption-api-cluster --services encryption-api-service`
- Check task definition: `aws ecs describe-task-definition --task-definition encryption-api`

## Performance

### Benchmarks (Local)
- Encryption: ~1ms per operation
- Database write: ~5ms
- End-to-end API call: ~10-20ms

### Production Recommendations
- Use connection pooling (configured: 10 max connections)
- Enable database query caching
- Use CDN for static content
- Implement API rate limiting
- Enable auto-scaling in ECS

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and test: `./mvnw verify`
4. Commit: `git commit -am 'Add new feature'`
5. Push: `git push origin feature/my-feature`
6. Create Pull Request

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/avi-xyz/encryption-api/issues)
- **Documentation**: See docs/ folder
- **Email**: [your-email@example.com]

## Roadmap

- [ ] Add API authentication (OAuth 2.0/JWT)
- [ ] Implement key rotation mechanism
- [ ] Add audit logging
- [ ] Create admin dashboard
- [ ] Support for batch encryption
- [ ] Add decryption endpoint with auth
- [ ] Implement rate limiting
- [ ] Multi-region deployment
- [ ] Performance monitoring dashboard
- [ ] Support for additional encryption algorithms

## Acknowledgments

- Spring Boot team for excellent framework
- Testcontainers for seamless integration testing
- AWS for robust cloud infrastructure
- Homebrew and VS Code for great developer tools

---

**Built with ❤️ using Spring Boot and deployed to AWS**

For detailed architecture and technical documentation, see [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md)
