###############################################################
# Terraform Setup
###############################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

###############################################################
# IAM Role for Lambda Functions
###############################################################
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_prefix}-lambda-exec-${var.environment}"

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
}

# Attach necessary managed policies
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_sns" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

###############################################################
# Core Resources: SQS, DynamoDB, SNS
###############################################################
# --- SQS Queue for async jobs ---
resource "aws_sqs_queue" "async_queue" {
  name                      = "${var.project_prefix}-async-job-queue-${var.environment}"
  visibility_timeout_seconds = 400
}

# --- DynamoDB Table to store job status ---
resource "aws_dynamodb_table" "jobs" {
  name         = "${var.project_prefix}-job-status-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id"

  attribute {
    name = "job_id"
    type = "S"
  }
}

# --- SNS Topics ---
resource "aws_sns_topic" "notifications_success" {
  name = "${var.project_prefix}-job-success-topic-${var.environment}"
}

resource "aws_sns_topic" "notifications_failure" {
  name = "${var.project_prefix}-job-failure-topic-${var.environment}"
}

###############################################################
# SNS Email Subscriptions
###############################################################
resource "aws_sns_topic_subscription" "success_email" {
  topic_arn = aws_sns_topic.notifications_success.arn
  protocol  = "email"
  endpoint  = "X"
}

resource "aws_sns_topic_subscription" "failure_email" {
  topic_arn = aws_sns_topic.notifications_failure.arn
  protocol  = "email"
  endpoint  = "X"
}


###############################################################
# Lambda Functions
###############################################################
# --- Sync Lambda ---
resource "aws_lambda_function" "lambda_sync" {
  function_name = "${var.project_prefix}-sync-lambda-${var.environment}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = var.lambda_runtime
  filename      = "${path.module}/lambda_sync.zip"
  timeout       = 30
  memory_size   = 128
}

# --- Async Lambda ---
resource "aws_lambda_function" "lambda_async" {
  function_name = "${var.project_prefix}-async-lambda-${var.environment}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = var.lambda_runtime
  filename      = "${path.module}/lambda_async.zip"
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      QUEUE_URL  = aws_sqs_queue.async_queue.url
      TABLE_NAME = aws_dynamodb_table.jobs.name
    }
  }
}

# --- Worker Lambda (triggered by SQS) ---
resource "aws_lambda_function" "lambda_worker" {
  function_name = "${var.project_prefix}-worker-lambda-${var.environment}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = var.lambda_runtime
  filename      = "${path.module}/lambda_worker.zip"
  timeout       = 300
  memory_size   = 256

  environment {
    variables = {
      TABLE_NAME         = aws_dynamodb_table.jobs.name
      TOPIC_SUCCESS_ARN  = aws_sns_topic.notifications_success.arn
      TOPIC_FAILURE_ARN  = aws_sns_topic.notifications_failure.arn
    }
  }
}

###############################################################
# CloudWatch Log Groups (explicit, safer)
###############################################################
resource "aws_cloudwatch_log_group" "sync_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_sync.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "async_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_async.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "worker_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_worker.function_name}"
  retention_in_days = 7
}

###############################################################
# SQS Event Source Mapping
###############################################################
resource "aws_lambda_event_source_mapping" "worker_trigger" {
  event_source_arn = aws_sqs_queue.async_queue.arn
  function_name    = aws_lambda_function.lambda_worker.arn
  batch_size       = 1
  enabled          = true
}

###############################################################
# API Gateway Setup
###############################################################
resource "aws_apigatewayv2_api" "serverless_api" {
  name          = "${var.project_prefix}-api-${var.environment}"
  protocol_type = "HTTP"
}

# --- Lambda Integrations ---
resource "aws_apigatewayv2_integration" "sync_integration" {
  api_id           = aws_apigatewayv2_api.serverless_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.lambda_sync.invoke_arn
}

resource "aws_apigatewayv2_integration" "async_integration" {
  api_id           = aws_apigatewayv2_api.serverless_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.lambda_async.invoke_arn
}

# --- Routes ---
resource "aws_apigatewayv2_route" "sync_route" {
  api_id    = aws_apigatewayv2_api.serverless_api.id
  route_key = "POST /sync"
  target    = "integrations/${aws_apigatewayv2_integration.sync_integration.id}"
}

resource "aws_apigatewayv2_route" "async_route" {
  api_id    = aws_apigatewayv2_api.serverless_api.id
  route_key = "POST /async"
  target    = "integrations/${aws_apigatewayv2_integration.async_integration.id}"
}

# --- Stage (auto-deploy enabled) ---
resource "aws_apigatewayv2_stage" "prod_stage" {
  api_id      = aws_apigatewayv2_api.serverless_api.id
  name        = "prod"
  auto_deploy = true
}

# --- Permissions for API Gateway to invoke Lambdas ---
resource "aws_lambda_permission" "allow_sync" {
  statement_id  = "AllowAPIGatewayInvokeSync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_sync.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.serverless_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_async" {
  statement_id  = "AllowAPIGatewayInvokeAsync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_async.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.serverless_api.execution_arn}/*/*"
}
