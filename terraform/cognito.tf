# ===========================================================================
# AWS Cognito User Pool for Authentication
# ===========================================================================

resource "aws_cognito_user_pool" "encryption_api" {
  name = "${var.project_name}-user-pool-${var.environment}"

  # Username and email configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attributes schema
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = false
    required                 = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 5
      max_length = 255
    }
  }

  schema {
    name                     = "name"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 255
    }
  }

  # Email configuration (using Cognito's default email)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User pool MFA configuration (optional)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Admin create user configuration
  admin_create_user_config {
    allow_admin_create_user_only = false

    invite_message_template {
      email_subject = "Your Encryption API account"
      email_message = "Your username is {username} and temporary password is {####}."
      sms_message   = "Your username is {username} and temporary password is {####}."
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Verification message templates
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Verify your email for Encryption API"
    email_message        = "Your verification code is {####}"
  }

  # Device configuration
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  # Tags
  tags = {
    Name        = "${var.project_name}-user-pool"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ===========================================================================
# Cognito User Pool Client (App Client)
# ===========================================================================

resource "aws_cognito_user_pool_client" "api_client" {
  name         = "${var.project_name}-api-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.encryption_api.id

  # OAuth and authentication flows
  generate_secret = false # Public client for direct API access

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_CUSTOM_AUTH"
  ]

  # Token validity configuration
  access_token_validity  = 60  # 60 minutes
  id_token_validity      = 60  # 60 minutes
  refresh_token_validity = 30  # 30 days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Read/write attributes
  read_attributes = [
    "email",
    "email_verified",
    "name"
  ]

  write_attributes = [
    "email",
    "name"
  ]

  # Security settings
  prevent_user_existence_errors = "ENABLED"

  # Enable token revocation
  enable_token_revocation = true

  # Refresh token rotation
  enable_propagate_additional_user_context_data = false
}

# ===========================================================================
# Cognito User Pool Domain (for hosted UI - optional)
# ===========================================================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-auth-${var.environment}-${random_id.cognito_domain_suffix.hex}"
  user_pool_id = aws_cognito_user_pool.encryption_api.id
}

resource "random_id" "cognito_domain_suffix" {
  byte_length = 4
}

# ===========================================================================
# CloudWatch Log Group for Cognito (optional - for advanced logging)
# ===========================================================================

resource "aws_cloudwatch_log_group" "cognito_logs" {
  name              = "/aws/cognito/user-pool/${aws_cognito_user_pool.encryption_api.name}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-cognito-logs"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ===========================================================================
# Outputs
# ===========================================================================

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.encryption_api.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.encryption_api.arn
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.encryption_api.endpoint
}

output "cognito_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.api_client.id
}

output "cognito_domain" {
  description = "Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_hosted_ui_url" {
  description = "Cognito Hosted UI URL (for testing)"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

# ===========================================================================
# SSM Parameter Store - Store Cognito configuration
# ===========================================================================

resource "aws_ssm_parameter" "cognito_user_pool_id" {
  name        = "/${var.project_name}/${var.environment}/cognito/user-pool-id"
  description = "Cognito User Pool ID for ${var.project_name}"
  type        = "String"
  value       = aws_cognito_user_pool.encryption_api.id

  tags = {
    Name        = "${var.project_name}-cognito-pool-id"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "cognito_client_id" {
  name        = "/${var.project_name}/${var.environment}/cognito/client-id"
  description = "Cognito Client ID for ${var.project_name}"
  type        = "String"
  value       = aws_cognito_user_pool_client.api_client.id

  tags = {
    Name        = "${var.project_name}-cognito-client-id"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
