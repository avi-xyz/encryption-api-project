# Encryption API - Project Architecture

## Overview
This project implements a production-ready REST API that encrypts strings using AES-256-GCM encryption and stores them securely in MySQL 8.

## Technology Stack

### Backend
- **Java 17**: LTS version with modern features
- **Spring Boot 3.x**: Framework for building the REST API
- **Spring Data JPA**: Database access and ORM
- **MySQL 8**: Relational database for encrypted data storage
- **JUnit 5 & Testcontainers**: Testing framework with container-based integration tests

### Encryption
- **AES-256-GCM**: Advanced Encryption Standard with Galois/Counter Mode
  - 256-bit key size (strongest AES variant)
  - Authenticated encryption (prevents tampering)
  - Provides both confidentiality and integrity
  - Industry standard for sensitive data

### Containerization & Deployment
- **Docker**: Container runtime
- **Docker Compose**: Local multi-container orchestration
- **AWS ECS Fargate**: Serverless container deployment
- **AWS RDS MySQL**: Managed database service
- **Terraform**: Infrastructure as Code

### CI/CD
- **GitHub Actions**: Automated testing and deployment
- **Maven**: Build and dependency management

## Project Structure

```
encryption-api-project/
├── src/
│   ├── main/
│   │   ├── java/com/aviencryption/
│   │   │   ├── EncryptionApiApplication.java    # Main Spring Boot application
│   │   │   ├── controller/
│   │   │   │   └── EncryptionController.java    # REST API endpoints
│   │   │   ├── service/
│   │   │   │   └── EncryptionService.java       # Business logic & encryption
│   │   │   ├── repository/
│   │   │   │   └── EncryptedDataRepository.java # Database access
│   │   │   ├── model/
│   │   │   │   └── EncryptedData.java           # JPA entity
│   │   │   └── config/
│   │   │       └── SecurityConfig.java          # Security configuration
│   │   └── resources/
│   │       ├── application.yml                  # Default configuration
│   │       ├── application-local.yml            # Local development config
│   │       └── application-prod.yml             # Production config
│   └── test/
│       └── java/com/aviencryption/
│           ├── controller/
│           │   └── EncryptionControllerTest.java
│           ├── service/
│           │   └── EncryptionServiceTest.java
│           └── integration/
│               └── EncryptionApiIntegrationTest.java
├── terraform/
│   ├── main.tf                                  # AWS infrastructure
│   ├── variables.tf                             # Terraform variables
│   └── outputs.tf                               # Infrastructure outputs
├── .github/
│   └── workflows/
│       └── ci-cd.yml                            # GitHub Actions pipeline
├── scripts/
│   └── setup-mac.sh                             # Automated macOS setup
├── Dockerfile                                    # Container image definition
├── docker-compose.yml                            # Local development environment
├── pom.xml                                       # Maven dependencies
└── README.md                                     # Main documentation
```

## Data Flow

1. **Client Request**: POST /api/encrypt with JSON payload `{"plainText": "secret"}`
2. **Encryption Service**:
   - Generates random 256-bit encryption key (per record)
   - Generates random 96-bit IV (Initialization Vector)
   - Encrypts plaintext using AES-256-GCM
   - Produces ciphertext + authentication tag
3. **Database Storage**: Stores encrypted data, IV, and encryption key (securely)
4. **Response**: Returns record ID and confirmation

## Security Considerations

### Encryption Details
- **Algorithm**: AES/GCM/NoPadding
- **Key Size**: 256 bits (32 bytes)
- **IV Size**: 96 bits (12 bytes) - optimal for GCM
- **Authentication Tag**: 128 bits (automatically handled by GCM)

### Key Management
- Each record uses a unique encryption key
- Keys are stored encrypted with a master key from AWS Secrets Manager (production)
- Local development uses environment-based key for simplicity

### Database Security
- Encrypted data stored as binary (BLOB/VARBINARY)
- TLS/SSL connections enforced
- Least-privilege database user

## Deployment Environments

### Local Development
- Docker Compose with MySQL container
- Application runs on port 8080
- Database on port 3306
- Hot reload enabled

### AWS Production
- **Compute**: ECS Fargate (serverless containers)
- **Database**: RDS MySQL 8 (Multi-AZ for high availability)
- **Secrets**: AWS Secrets Manager for master encryption key
- **Networking**: VPC with private subnets
- **Load Balancer**: Application Load Balancer (HTTPS)

## Testing Strategy

### Unit Tests
- Service layer encryption/decryption logic
- Controller input validation
- Mocked dependencies

### Integration Tests
- Full API workflow with real MySQL (Testcontainers)
- Database transactions
- Error handling scenarios
- Automatic setup and teardown

### Test Database
- Testcontainers spins up ephemeral MySQL instance
- Tests run in isolation
- No manual cleanup required

## Build & Deployment Process

### Local Development
```bash
./scripts/setup-mac.sh  # One-time setup
docker-compose up       # Start MySQL
./mvnw spring-boot:run  # Run application
./mvnw test            # Run all tests
```

### CI/CD Pipeline
1. **Trigger**: Push to main branch or pull request
2. **Build**: Compile and run tests
3. **Docker**: Build and push image to registry
4. **Deploy**: Update ECS service with new image
5. **Verify**: Health check endpoint

## API Endpoints

### POST /api/encrypt
Encrypts a string and stores it in the database.

**Request**:
```json
{
  "plainText": "my secret message"
}
```

**Response**:
```json
{
  "id": 1,
  "timestamp": "2025-11-19T10:30:00Z",
  "message": "Data encrypted successfully"
}
```

### GET /api/health
Health check endpoint for load balancers.

**Response**:
```json
{
  "status": "UP",
  "database": "CONNECTED"
}
```

## Environment Variables

### Required
- `SPRING_DATASOURCE_URL`: Database connection URL
- `SPRING_DATASOURCE_USERNAME`: Database username
- `SPRING_DATASOURCE_PASSWORD`: Database password
- `ENCRYPTION_MASTER_KEY`: Master key for key encryption (base64-encoded)

### Optional
- `SERVER_PORT`: Application port (default: 8080)
- `SPRING_PROFILES_ACTIVE`: Active profile (local/prod)

## Future Enhancements
- Decryption endpoint with authentication
- Key rotation mechanism
- Audit logging
- Rate limiting
- Multi-region deployment
