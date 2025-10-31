###############################################################
# Variables
###############################################################

# --- AWS Region ---
variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "eu-central-1"
}

# --- Lambda Runtime ---
variable "lambda_runtime" {
  description = "Python runtime version for Lambda functions"
  type        = string
  default     = "python3.11"
}

# --- Project Prefix ---
variable "project_prefix" {
  description = "Prefix added to all AWS resource names"
  type        = string
  default     = "serverless-async"
}

# --- SQS Queue ---
variable "sqs_queue_name" {
  description = "Base name for the SQS queue used for asynchronous jobs"
  type        = string
  default     = "async-job-queue"
}

# --- DynamoDB Table ---
variable "dynamodb_table_name" {
  description = "Base name for the DynamoDB table that tracks job statuses"
  type        = string
  default     = "job-status"
}

# --- SNS Topics ---
variable "sns_topic_success_name" {
  description = "Base name for the SNS topic that publishes success job notifications"
  type        = string
  default     = "job-success-topic"
}

variable "sns_topic_failure_name" {
  description = "Base name for the SNS topic that publishes failed job notifications"
  type        = string
  default     = "job-failure-topic"
}

# --- Environment ---
variable "environment" {
  description = "Deployment environment (e.g., dev, test, prod)"
  type        = string
  default     = "dev"
}
