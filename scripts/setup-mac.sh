#!/bin/bash

###############################################################################
# Encryption API - Automated macOS Setup Script
#
# This script automates the complete setup of the development environment on macOS:
# - Installs Homebrew (if not present)
# - Installs Java 17, Maven, Docker, Git, and other dependencies
# - Installs VS Code and required extensions
# - Configures VS Code settings for Java development
# - Sets up Git repository
# - Builds and tests the project
# - Starts local development environment with Docker Compose
#
# Usage:
#   chmod +x scripts/setup-mac.sh
#   ./scripts/setup-mac.sh
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only!"
    exit 1
fi

print_header "Encryption API - macOS Development Environment Setup"

###############################################################################
# 1. Install Homebrew
###############################################################################
print_header "Step 1: Installing Homebrew"

if command -v brew &> /dev/null; then
    print_success "Homebrew is already installed"
    brew --version
else
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    print_success "Homebrew installed successfully"
fi

###############################################################################
# 2. Install Java 17
###############################################################################
print_header "Step 2: Installing Java 17 (Temurin)"

if command -v java &> /dev/null && java -version 2>&1 | grep -q "17"; then
    print_success "Java 17 is already installed"
    java -version
else
    print_info "Installing Java 17 (Eclipse Temurin)..."
    brew install --cask temurin@17

    # Set JAVA_HOME
    export JAVA_HOME=$(/usr/libexec/java_home -v 17)
    echo "export JAVA_HOME=\$(/usr/libexec/java_home -v 17)" >> ~/.zshrc

    print_success "Java 17 installed successfully"
    java -version
fi

###############################################################################
# 3. Install Maven
###############################################################################
print_header "Step 3: Installing Maven"

if command -v mvn &> /dev/null; then
    print_success "Maven is already installed"
    mvn --version
else
    print_info "Installing Maven..."
    brew install maven
    print_success "Maven installed successfully"
    mvn --version
fi

###############################################################################
# 4. Install Docker Desktop
###############################################################################
print_header "Step 4: Installing Docker Desktop"

if command -v docker &> /dev/null; then
    print_success "Docker is already installed"
    docker --version
else
    print_info "Installing Docker Desktop..."
    brew install --cask docker
    print_warning "Please start Docker Desktop manually from Applications folder"
    print_warning "Press Enter after Docker Desktop is running..."
    read
fi

# Wait for Docker to be ready
print_info "Waiting for Docker to start..."
while ! docker info &> /dev/null; do
    sleep 2
done
print_success "Docker is running"

###############################################################################
# 5. Install Git
###############################################################################
print_header "Step 5: Installing Git"

if command -v git &> /dev/null; then
    print_success "Git is already installed"
    git --version
else
    print_info "Installing Git..."
    brew install git
    print_success "Git installed successfully"
fi

###############################################################################
# 6. Install VS Code
###############################################################################
print_header "Step 6: Installing Visual Studio Code"

if [ -d "/Applications/Visual Studio Code.app" ]; then
    print_success "VS Code is already installed"
else
    print_info "Installing VS Code..."
    brew install --cask visual-studio-code
    print_success "VS Code installed successfully"
fi

# Install VS Code command line tools
print_info "Installing VS Code command line tools..."
if ! command -v code &> /dev/null; then
    cat << EOF
Please install VS Code command line tools manually:
1. Open VS Code
2. Press Cmd+Shift+P
3. Type "shell command"
4. Select "Install 'code' command in PATH"
5. Press Enter when done

Press Enter to continue...
EOF
    read
fi

###############################################################################
# 7. Install VS Code Extensions
###############################################################################
print_header "Step 7: Installing VS Code Extensions"

# Required extensions for Java development
EXTENSIONS=(
    "vscjava.vscode-java-pack"           # Java Extension Pack
    "vscjava.vscode-spring-boot-dashboard" # Spring Boot Dashboard
    "vmware.vscode-spring-boot"          # Spring Boot Tools
    "redhat.java"                        # Language Support for Java
    "vscjava.vscode-java-debug"          # Debugger for Java
    "vscjava.vscode-java-test"           # Test Runner for Java
    "vscjava.vscode-maven"               # Maven for Java
    "vscjava.vscode-java-dependency"     # Project Manager for Java
    "ms-azuretools.vscode-docker"        # Docker
    "github.vscode-pull-request-github"  # GitHub Pull Requests
    "eamodio.gitlens"                    # GitLens
    "redhat.vscode-yaml"                 # YAML
    "streetsidesoftware.code-spell-checker" # Spell Checker
)

for extension in "${EXTENSIONS[@]}"; do
    print_info "Installing VS Code extension: $extension"
    code --install-extension "$extension" --force
done

print_success "All VS Code extensions installed"

###############################################################################
# 8. Configure VS Code Settings
###############################################################################
print_header "Step 8: Configuring VS Code Settings"

VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_SETTINGS_DIR"

# Create settings.json
cat > "$VSCODE_SETTINGS_DIR/settings.json" << 'EOF'
{
    "java.configuration.runtimes": [
        {
            "name": "JavaSE-17",
            "path": "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
            "default": true
        }
    ],
    "java.home": "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
    "java.jdt.ls.java.home": "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home",
    "maven.terminal.useJavaHome": true,
    "java.format.settings.url": "${workspaceFolder}/.vscode/java-formatter.xml",
    "editor.formatOnSave": true,
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "java.saveActions.organizeImports": true,
    "spring-boot.ls.checkJVM": false,
    "java.test.config": {
        "workingDirectory": "${workspaceFolder}"
    }
}
EOF

print_success "VS Code settings configured"

###############################################################################
# 9. Create VS Code Workspace Configuration
###############################################################################
print_header "Step 9: Creating VS Code Workspace Configuration"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/.vscode"

# Create launch.json for debugging
cat > "$PROJECT_ROOT/.vscode/launch.json" << 'EOF'
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "java",
            "name": "Launch Encryption API",
            "request": "launch",
            "mainClass": "com.aviencryption.EncryptionApiApplication",
            "projectName": "encryption-api",
            "args": "--spring.profiles.active=local",
            "env": {
                "SPRING_PROFILES_ACTIVE": "local"
            }
        },
        {
            "type": "java",
            "name": "Debug Tests",
            "request": "launch",
            "mainClass": "",
            "projectName": "encryption-api",
            "preLaunchTask": "test"
        }
    ]
}
EOF

# Create tasks.json for build tasks
cat > "$PROJECT_ROOT/.vscode/tasks.json" << 'EOF'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build",
            "type": "shell",
            "command": "./mvnw clean package -DskipTests",
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": []
        },
        {
            "label": "test",
            "type": "shell",
            "command": "./mvnw test",
            "group": {
                "kind": "test",
                "isDefault": true
            },
            "problemMatcher": []
        },
        {
            "label": "run",
            "type": "shell",
            "command": "./mvnw spring-boot:run -Dspring-boot.run.profiles=local",
            "group": "none",
            "problemMatcher": []
        },
        {
            "label": "docker-up",
            "type": "shell",
            "command": "docker-compose up -d",
            "group": "none",
            "problemMatcher": []
        },
        {
            "label": "docker-down",
            "type": "shell",
            "command": "docker-compose down",
            "group": "none",
            "problemMatcher": []
        }
    ]
}
EOF

# Create extensions.json with recommended extensions
cat > "$PROJECT_ROOT/.vscode/extensions.json" << 'EOF'
{
    "recommendations": [
        "vscjava.vscode-java-pack",
        "vscjava.vscode-spring-boot-dashboard",
        "vmware.vscode-spring-boot",
        "ms-azuretools.vscode-docker",
        "github.vscode-pull-request-github",
        "eamodio.gitlens",
        "redhat.vscode-yaml"
    ]
}
EOF

print_success "VS Code workspace configured"

###############################################################################
# 10. Install Additional Tools
###############################################################################
print_header "Step 10: Installing Additional Development Tools"

# Install Terraform
if command -v terraform &> /dev/null; then
    print_success "Terraform is already installed"
else
    print_info "Installing Terraform..."
    brew install terraform
    print_success "Terraform installed"
fi

# Install AWS CLI
if command -v aws &> /dev/null; then
    print_success "AWS CLI is already installed"
else
    print_info "Installing AWS CLI..."
    brew install awscli
    print_success "AWS CLI installed"
fi

# Install jq (JSON processor)
if command -v jq &> /dev/null; then
    print_success "jq is already installed"
else
    print_info "Installing jq..."
    brew install jq
    print_success "jq installed"
fi

# Install curl (usually pre-installed)
if ! command -v curl &> /dev/null; then
    brew install curl
fi

###############################################################################
# 11. Make Maven Wrapper Executable
###############################################################################
print_header "Step 11: Configuring Maven Wrapper"

cd "$PROJECT_ROOT"
if [ -f ".mvn/wrapper/maven-wrapper.jar" ]; then
    chmod +x mvnw
    print_success "Maven wrapper is properly configured"
else
    print_info "Generating Maven wrapper..."
    mvn wrapper:wrapper
    chmod +x mvnw
    print_success "Maven wrapper generated and configured"
fi

###############################################################################
# 12. Build the Project
###############################################################################
print_header "Step 12: Building the Project"

print_info "Running Maven build (this may take a few minutes)..."
./mvnw clean package -DskipTests

print_success "Project built successfully"

###############################################################################
# 13. Run Tests
###############################################################################
print_header "Step 13: Running Tests"

print_info "Running unit and integration tests..."
./mvnw verify

print_success "All tests passed"

###############################################################################
# 14. Start Development Environment
###############################################################################
print_header "Step 14: Starting Development Environment"

print_info "Starting MySQL with Docker Compose..."
docker-compose up -d mysql

print_info "Waiting for MySQL to be ready..."
sleep 10

print_success "MySQL is running on port 3306"

###############################################################################
# 15. Git Configuration
###############################################################################
print_header "Step 15: Git Configuration"

if [ -d ".git" ]; then
    print_success "Git repository already initialized"
else
    print_info "Initializing Git repository..."
    git init
    print_success "Git repository initialized"
fi

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    cat > .gitignore << 'EOF'
# Maven
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup

# IDE
.idea/
*.iml
.vscode/settings.json
.DS_Store

# Terraform
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/terraform.tfvars

# Environment
.env
*.log

# Test
test-output/
EOF
    print_success ".gitignore created"
fi

###############################################################################
# Setup Complete
###############################################################################
print_header "Setup Complete!"

cat << EOF

${GREEN}✓ Development environment is ready!${NC}

${BLUE}Installed:${NC}
  - Java 17 (Temurin)
  - Maven
  - Docker Desktop
  - Visual Studio Code with Java extensions
  - Terraform
  - AWS CLI
  - Git

${BLUE}Services Running:${NC}
  - MySQL on port 3306

${BLUE}Next Steps:${NC}

  1. Start the application:
     ${YELLOW}./mvnw spring-boot:run -Dspring-boot.run.profiles=local${NC}

  2. Test the API:
     ${YELLOW}curl http://localhost:8080/api/health${NC}
     ${YELLOW}curl -X POST http://localhost:8080/api/encrypt \\
       -H "Content-Type: application/json" \\
       -d '{"plainText":"Hello World!"}'${NC}

  3. Open in VS Code:
     ${YELLOW}code .${NC}

  4. Configure AWS credentials (for deployment):
     ${YELLOW}aws configure${NC}

  5. Initialize Terraform (for AWS deployment):
     ${YELLOW}cd terraform && terraform init${NC}

${BLUE}Useful Commands:${NC}
  - Run tests: ${YELLOW}./mvnw test${NC}
  - Build: ${YELLOW}./mvnw clean package${NC}
  - Start Docker: ${YELLOW}docker-compose up${NC}
  - Stop Docker: ${YELLOW}docker-compose down${NC}
  - View logs: ${YELLOW}docker-compose logs -f${NC}

${BLUE}Documentation:${NC}
  - README.md - General documentation
  - PROJECT_ARCHITECTURE.md - Architecture overview
  - terraform/README.md - AWS deployment guide

${GREEN}Happy coding! 🚀${NC}

EOF
