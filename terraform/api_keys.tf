# ===========================================================================
# API Gateway API Keys for Authentication Layer 1
# ===========================================================================

# Primary API Key
resource "aws_api_gateway_api_key" "primary" {
  name        = "${var.project_name}-primary-key-${var.environment}"
  description = "Primary API key for ${var.project_name}"
  enabled     = true

  tags = {
    Name        = "${var.project_name}-primary-api-key"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    KeyType     = "primary"
  }
}

# Secondary API Key (for rotation)
resource "aws_api_gateway_api_key" "secondary" {
  name        = "${var.project_name}-secondary-key-${var.environment}"
  description = "Secondary API key for rotation - ${var.project_name}"
  enabled     = false # Disabled by default, enable during rotation

  tags = {
    Name        = "${var.project_name}-secondary-api-key"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    KeyType     = "secondary"
  }
}

# ===========================================================================
# Store API Keys in AWS Secrets Manager
# ===========================================================================

resource "aws_secretsmanager_secret" "api_keys" {
  name        = "${var.project_name}/${var.environment}/api-keys"
  description = "API Gateway keys for ${var.project_name}"

  tags = {
    Name        = "${var.project_name}-api-keys"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id

  secret_string = jsonencode({
    primary_key   = aws_api_gateway_api_key.primary.value
    primary_id    = aws_api_gateway_api_key.primary.id
    secondary_key = aws_api_gateway_api_key.secondary.value
    secondary_id  = aws_api_gateway_api_key.secondary.id
    rotation_date = timestamp()
  })
}

# ===========================================================================
# Lambda Function for API Key Rotation
# ===========================================================================

# IAM Role for API Key Rotation Lambda
resource "aws_iam_role" "api_key_rotation" {
  name = "${var.project_name}-api-key-rotation-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-api-key-rotation-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM Policy for API Key Rotation
resource "aws_iam_role_policy" "api_key_rotation" {
  name = "${var.project_name}-api-key-rotation-policy"
  role = aws_iam_role.api_key_rotation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:DELETE",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH"
        ]
        Resource = "arn:aws:apigateway:${var.aws_region}::/apikeys/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret"
        ]
        Resource = aws_secretsmanager_secret.api_keys.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function code (inline for simplicity)
resource "aws_lambda_function" "api_key_rotation" {
  filename      = "${path.module}/lambda/api_key_rotation.zip"
  function_name = "${var.project_name}-api-key-rotation"
  role          = aws_iam_role.api_key_rotation.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      SECRET_ARN     = aws_secretsmanager_secret.api_keys.arn
      PRIMARY_KEY_ID = aws_api_gateway_api_key.primary.id
      SECONDARY_KEY_ID = aws_api_gateway_api_key.secondary.id
      AWS_REGION_VAR = var.aws_region
    }
  }

  tags = {
    Name        = "${var.project_name}-api-key-rotation"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Group for rotation function
resource "aws_cloudwatch_log_group" "api_key_rotation" {
  name              = "/aws/lambda/${aws_lambda_function.api_key_rotation.function_name}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-api-key-rotation-logs"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ===========================================================================
# EventBridge Rule for Scheduled API Key Rotation (every 90 days)
# ===========================================================================

resource "aws_cloudwatch_event_rule" "api_key_rotation_schedule" {
  name                = "${var.project_name}-api-key-rotation-schedule"
  description         = "Trigger API key rotation every 90 days"
  schedule_expression = "rate(90 days)"

  tags = {
    Name        = "${var.project_name}-api-key-rotation-schedule"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "api_key_rotation" {
  rule      = aws_cloudwatch_event_rule.api_key_rotation_schedule.name
  target_id = "ApiKeyRotationLambda"
  arn       = aws_lambda_function.api_key_rotation.arn
}

resource "aws_lambda_permission" "allow_eventbridge_rotation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_key_rotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.api_key_rotation_schedule.arn
}

# ===========================================================================
# Outputs
# ===========================================================================

output "primary_api_key_id" {
  description = "ID of the primary API key"
  value       = aws_api_gateway_api_key.primary.id
}

output "secondary_api_key_id" {
  description = "ID of the secondary API key"
  value       = aws_api_gateway_api_key.secondary.id
}

output "api_keys_secret_arn" {
  description = "ARN of the Secrets Manager secret containing API keys"
  value       = aws_secretsmanager_secret.api_keys.arn
}

output "api_key_rotation_function_name" {
  description = "Name of the API key rotation Lambda function"
  value       = aws_lambda_function.api_key_rotation.function_name
}
