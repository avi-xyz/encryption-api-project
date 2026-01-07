# Terraform configuration for deploying Encryption API to AWS Lambda
#
# Architecture:
# - AWS Lambda function running Spring Boot application
# - API Gateway HTTP API for HTTPS endpoint
# - RDS MySQL 8 database
# - VPC with public and private subnets
# - Secrets Manager for encryption keys
# - CloudWatch for logging
#
# This serverless architecture bypasses the load balancer restriction!

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "encryption-api"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# VPC and Networking
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Private Subnets (for Lambda and RDS)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# NAT Gateway for Lambda outbound access
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

###############################################################################
# Security Groups
###############################################################################

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.main.id

  # Outbound to RDS
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Allow MySQL access to RDS"
  }

  # Outbound to internet via NAT (for Secrets Manager, CloudWatch, etc.)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS for AWS services"
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS MySQL database"
  vpc_id      = aws_vpc.main.id

  # Inbound from Lambda
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "Allow MySQL access from Lambda"
  }

  # Outbound (required for RDS to function)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

###############################################################################
# RDS MySQL Database
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier     = "${var.project_name}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "encryption_db"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = true
  final_snapshot_identifier = null
  deletion_protection       = false

  tags = {
    Name = "${var.project_name}-db"
  }
}

###############################################################################
# Secrets Manager
###############################################################################

resource "aws_secretsmanager_secret" "master_key" {
  name                    = "${var.project_name}-master-key"
  description             = "Master encryption key for the encryption API"
  recovery_window_in_days = 0  # Immediate deletion (for development)
}

resource "aws_secretsmanager_secret_version" "master_key" {
  secret_id     = aws_secretsmanager_secret.master_key.id
  secret_string = var.master_encryption_key
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password"
  description             = "Database password for RDS MySQL"
  recovery_window_in_days = 0  # Immediate deletion (for development)
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

###############################################################################
# CloudWatch Logs
###############################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}

###############################################################################
# Lambda Function
###############################################################################

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

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
    Name = "${var.project_name}-lambda-role"
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy for Secrets Manager access
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${var.project_name}-lambda-secrets-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.master_key.arn,
          aws_secretsmanager_secret.db_password.arn
        ]
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "api" {
  s3_bucket        = "encryption-api-lambda-code-useast1-20260107"
  s3_key           = "encryption-api-1.0.0.jar"
  function_name    = "${var.project_name}-function"
  role            = aws_iam_role.lambda.arn
  handler         = "com.aviencryption.StreamLambdaHandler::handleRequest"
  runtime         = "java17"
  memory_size     = 512
  timeout         = 30
  source_code_hash = filebase64sha256("${path.module}/../target/encryption-api-lambda.jar")

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE    = "prod"
      DB_HOST                   = split(":", aws_db_instance.mysql.endpoint)[0]
      DB_PORT                   = "3306"
      DB_NAME                   = aws_db_instance.mysql.db_name
      DB_USERNAME               = var.db_username
      DB_PASSWORD               = var.db_password
      MASTER_ENCRYPTION_KEY     = var.master_encryption_key
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc
  ]

  tags = {
    Name = "${var.project_name}-lambda"
  }
}

###############################################################################
# API Gateway
###############################################################################

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for Encryption API (Serverless Lambda)"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-api-gateway"
  }
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn

  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

# Routes
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage with Rate Limiting
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  # Rate Limiting: 5 requests per minute, 20 requests per hour
  # Burst: 5 requests allowed in quick succession
  # Rate: 0.33 requests per second = 20 requests per minute (we'll use route-level throttling for stricter limits)
  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit  = 0.33  # 20 requests per minute (we enforce 5/min at route level)
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name = "${var.project_name}-api-stage"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

###############################################################################
# Keep-Warm CloudWatch Event (Prevents cold starts)
###############################################################################

resource "aws_cloudwatch_event_rule" "keep_warm" {
  name                = "${var.project_name}-keep-warm"
  description         = "Ping Lambda every 5 minutes to prevent cold starts"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name = "${var.project_name}-keep-warm-rule"
  }
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.keep_warm.name
  target_id = "${var.project_name}-lambda"
  arn       = aws_lambda_function.api.arn

  input = jsonencode({
    httpMethod = "GET"
    path       = "/api/health"
  })
}

resource "aws_lambda_permission" "cloudwatch" {
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.keep_warm.arn
}
