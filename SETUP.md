# Manual Setup Guide

This guide provides manual installation steps if you prefer not to use the automated setup script.

## Prerequisites

### 1. Install Homebrew (if not already installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Java 17
```bash
brew install --cask temurin@17

# Set JAVA_HOME
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
```

### 3. Install Maven
```bash
brew install maven
```

### 4. Install Docker Desktop
```bash
brew install --cask docker
```

Start Docker Desktop from Applications folder.

### 5. Install Git
```bash
brew install git
```

### 6. Install VS Code
```bash
brew install --cask visual-studio-code
```

### 7. Install VS Code Extensions

Open VS Code and install these extensions:
- Java Extension Pack (vscjava.vscode-java-pack)
- Spring Boot Tools (vmware.vscode-spring-boot)
- Spring Boot Dashboard (vscjava.vscode-spring-boot-dashboard)
- Docker (ms-azuretools.vscode-docker)
- GitLens (eamodio.gitlens)

Or use command line:
```bash
code --install-extension vscjava.vscode-java-pack
code --install-extension vmware.vscode-spring-boot
code --install-extension vscjava.vscode-spring-boot-dashboard
code --install-extension ms-azuretools.vscode-docker
code --install-extension eamodio.gitlens
```

## Project Setup

### 1. Clone the Repository
```bash
git clone https://github.com/avi-xyz/encryption-api.git
cd encryption-api
```

### 2. Build the Project
```bash
./mvnw clean package
```

### 3. Run Tests
```bash
./mvnw verify
```

### 4. Start MySQL
```bash
docker-compose up -d mysql
```

### 5. Run the Application
```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

### 6. Test the API
```bash
# Health check
curl http://localhost:8080/api/health

# Encrypt data
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plainText":"Hello World!"}'
```

## Optional Tools

### Terraform (for AWS deployment)
```bash
brew install terraform
```

### AWS CLI (for AWS deployment)
```bash
brew install awscli
aws configure
```

## IDE Configuration

### VS Code Settings

Create `.vscode/settings.json`:
```json
{
    "java.configuration.runtimes": [
        {
            "name": "JavaSE-17",
            "path": "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
            "default": true
        }
    ],
    "java.home": "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
    "maven.terminal.useJavaHome": true,
    "editor.formatOnSave": true
}
```

## Troubleshooting

### Java Version Issues
Verify Java 17 is active:
```bash
java -version
```

Should show version 17.x.x

### Maven Wrapper Issues
If `./mvnw` doesn't work:
```bash
chmod +x mvnw
```

### Docker Not Starting
Check Docker Desktop is running:
```bash
docker info
```

### Port Already in Use
If port 8080 is in use:
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

## Next Steps

See [README.md](README.md) for:
- API usage examples
- Deployment instructions
- CI/CD setup
- AWS configuration
