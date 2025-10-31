import json
import time
import boto3
import os

# AWS clients
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

# Environment variables injected by Terraform
TABLE_NAME = os.environ.get("TABLE_NAME")
TOPIC_SUCCESS_ARN = os.environ.get("TOPIC_SUCCESS_ARN")
TOPIC_FAILURE_ARN = os.environ.get("TOPIC_FAILURE_ARN")

def handler(event, context):
    """
    Processes queued async jobs from SQS, updates DB,
    and publishes SNS notifications for both success and failure.
    """

    # Connect to DynamoDB table
    table = dynamodb.Table(TABLE_NAME)

    # Supported actions list
    supported_actions = ["generate_invoice", "generate_highlight", "send_email_notification"]

    # Loop through each message received from SQS
    for record in event.get("Records", []):
        body = json.loads(record["body"])
        job_id = body["job_id"]
        action = body["action"]
        data = body["data"]

        print(f"Processing job {job_id} for action '{action}'...")

        # Handle unsupported actions
        if action not in supported_actions:
            print(f"Unknown action '{action}' - marking job {job_id} as FAILED.")

            # Update DynamoDB with failed status
            table.update_item(
                Key={"job_id": job_id},
                UpdateExpression="SET #s = :s",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":s": "failed"}
            )

            # Publish failure notification
            sns.publish(
                TopicArn=TOPIC_FAILURE_ARN,
                Subject="Async Job Failed",
                Message=json.dumps({
                    "job_id": job_id,
                    "action": action,
                    "status": "failed",
                    "reason": f"Unsupported action '{action}'"
                })
            )

            # Continue to next message
            continue

        # Simulate job processing (mock)
        print(f"Processing job {job_id}...")
        time.sleep(3)  # Simulate work

        # Update DynamoDB job status -> completed
        table.update_item(
            Key={"job_id": job_id},
            UpdateExpression="SET #s = :s",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": "completed"}
        )

        print(f"Job {job_id} completed successfully for action '{action}'.")

        # Publish success notification
        sns.publish(
            TopicArn=TOPIC_SUCCESS_ARN,
            Subject="Async Job Completed",
            Message=json.dumps({
                "job_id": job_id,
                "action": action,
                "status": "completed"
            })
        )

    # Return final response for CloudWatch logs
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "All jobs processed."})
    }

