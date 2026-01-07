#!/bin/bash
set -e

echo "Creating Lambda-compatible JAR from Spring Boot Fat JAR..."

# Clean and build
./mvnw clean package -DskipTests

# Create temp directory
rm -rf lambda-build
mkdir -p lambda-build
cd lambda-build

# Unzip the fat JAR
echo "Extracting fat JAR..."
jar -xf ../target/encryption-api-1.0.0.jar

# Move BOOT-INF contents to root
echo "Restructuring for Lambda..."
if [ -d "BOOT-INF/classes" ]; then
    cp -r BOOT-INF/classes/* .
fi
if [ -d "BOOT-INF/lib" ]; then
    mkdir -p lib
    cp BOOT-INF/lib/* lib/
fi

# Remove BOOT-INF
rm -rf BOOT-INF META-INF/MANIFEST.MF

# Create new JAR
echo "Creating new JAR..."
jar -cf ../target/encryption-api-lambda.jar *

cd ..
ls -lh target/encryption-api-lambda.jar

echo "✅ Lambda JAR created: target/encryption-api-lambda.jar"
