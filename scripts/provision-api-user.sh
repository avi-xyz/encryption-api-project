#!/bin/bash

###############################################################################
# Encryption API - User Provisioning Script
#
# This script automates the creation of new API users in AWS Cognito.
# Use this when approving GitHub access request issues.
#
# Usage:
#   ./scripts/provision-api-user.sh <email> <full-name>
#
# Example:
#   ./scripts/provision-api-user.sh john.doe@example.com "John Doe"
#
# The script will:
# 1. Generate a secure random temporary password
# 2. Create the user in AWS Cognito
# 3. Set a permanent password (users can change this later)
# 4. Output credentials to share with the user
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
# TODO: Replace with your actual Cognito User Pool ID from terraform output
USER_POOL_ID="${COGNITO_USER_POOL_ID:-YOUR_USER_POOL_ID_HERE}"
AWS_REGION="us-east-1"

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo ""
    echo "Usage: $0 <email> [full-name]"
    echo ""
    echo "Examples:"
    echo "  $0 john.doe@example.com \"John Doe\""
    echo "  $0 jane@company.com"
    echo ""
    exit 1
fi

EMAIL="$1"
FULL_NAME="${2:-$EMAIL}"

# Validate email format
if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}Error: Invalid email address format${NC}"
    exit 1
fi

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Encryption API - User Provisioning${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "Email:     ${YELLOW}$EMAIL${NC}"
echo -e "Name:      ${YELLOW}$FULL_NAME${NC}"
echo -e "User Pool: ${YELLOW}$USER_POOL_ID${NC}"
echo ""

# Generate secure random password
echo -e "${BLUE}Generating secure password...${NC}"
TEMP_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
# Ensure password meets Cognito requirements (uppercase, lowercase, number, symbol)
PERMANENT_PASSWORD="${TEMP_PASSWORD}Aa1!"

echo -e "${GREEN}✓${NC} Password generated"
echo ""

# Check if user already exists
echo -e "${BLUE}Checking if user exists...${NC}"
if aws cognito-idp admin-get-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EMAIL" \
    --region "$AWS_REGION" &>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  User already exists in Cognito"
    echo ""
    read -p "Do you want to reset the password? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Aborted${NC}"
        exit 0
    fi

    # Reset password
    echo -e "${BLUE}Resetting password...${NC}"
    aws cognito-idp admin-set-user-password \
        --user-pool-id "$USER_POOL_ID" \
        --username "$EMAIL" \
        --password "$PERMANENT_PASSWORD" \
        --permanent \
        --region "$AWS_REGION"

    echo -e "${GREEN}✓${NC} Password reset successfully"

else
    # Create new user
    echo -e "${BLUE}Creating new user...${NC}"
    aws cognito-idp admin-create-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$EMAIL" \
        --user-attributes \
            Name=email,Value="$EMAIL" \
            Name=email_verified,Value=true \
            Name=name,Value="$FULL_NAME" \
        --temporary-password "$TEMP_PASSWORD" \
        --message-action SUPPRESS \
        --region "$AWS_REGION" &>/dev/null

    echo -e "${GREEN}✓${NC} User created successfully"

    # Set permanent password
    echo -e "${BLUE}Setting permanent password...${NC}"
    aws cognito-idp admin-set-user-password \
        --user-pool-id "$USER_POOL_ID" \
        --username "$EMAIL" \
        --password "$PERMANENT_PASSWORD" \
        --permanent \
        --region "$AWS_REGION" &>/dev/null

    echo -e "${GREEN}✓${NC} Password set successfully"
fi

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  ✓ User Provisioned Successfully!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo -e "${YELLOW}Share the following credentials with the user:${NC}"
echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Username:${NC} $EMAIL"
echo -e "${BLUE}Password:${NC} $PERMANENT_PASSWORD"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Instructions for the user:${NC}"
echo ""
echo "1. Test login with curl:"
echo ""
echo "   curl -X POST https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/api/auth/login \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"username\":\"$EMAIL\",\"password\":\"$PERMANENT_PASSWORD\"}'"
echo ""
echo "2. You'll receive a response with JWT tokens:"
echo "   - idToken: Use this in Authorization header for API calls"
echo "   - accessToken: Additional access token"
echo "   - refreshToken: Use to get new tokens without re-entering password"
echo ""
echo "3. Make API calls with the idToken:"
echo ""
echo "   curl -X POST https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/api/encrypt \\"
echo "     -H \"Authorization: Bearer YOUR_ID_TOKEN\" \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"plainText\":\"my secret data\"}'"
echo ""
echo -e "${BLUE}API Documentation:${NC} https://github.com/avi-xyz/encryption-api/blob/main/API_DOCUMENTATION.md"
echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
