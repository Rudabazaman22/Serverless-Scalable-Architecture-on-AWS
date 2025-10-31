###############################################################
# Terraform Outputs
###############################################################

# --- API Gateway Endpoint ---
output "api_endpoint" {
  description = "Invoke URL for API Gateway"
  value       = aws_apigatewayv2_stage.prod_stage.invoke_url
}

# --- SQS Queue URL ---
output "sqs_queue_url" {
  description = "URL of the asynchronous SQS queue"
  value       = aws_sqs_queue.async_queue.url
}

# --- DynamoDB Table Name ---
output "dynamodb_table" {
  description = "Name of the DynamoDB table tracking job status"
  value       = aws_dynamodb_table.jobs.name
}

# --- SNS Topic (Success) ---
output "sns_topic_success_arn" {
  description = "ARN of the SNS topic for successful jobs"
  value       = aws_sns_topic.notifications_success.arn
}

# --- SNS Topic (Failure) ---
output "sns_topic_failure_arn" {
  description = "ARN of the SNS topic for failed jobs"
  value       = aws_sns_topic.notifications_failure.arn
}
