# Terraform Outputs for Encryption API Infrastructure (Lambda)

output "api_gateway_url" {
  description = "API Gateway endpoint URL - use this to access the API"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.api.arn
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "Name of the RDS database"
  value       = aws_db_instance.mysql.db_name
}

output "cloudwatch_log_group_lambda" {
  description = "CloudWatch log group for Lambda logs"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_api_gateway" {
  description = "CloudWatch log group for API Gateway logs"
  value       = aws_cloudwatch_log_group.api_gateway.name
}
