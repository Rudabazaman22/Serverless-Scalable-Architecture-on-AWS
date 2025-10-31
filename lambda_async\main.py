import json
import uuid
import boto3
import time
import os

# Clients
sqs = boto3.client("sqs")
dynamodb = boto3.resource("dynamodb")

# Environment variables injected by Terraform
QUEUE_URL = os.environ.get("QUEUE_URL")
TABLE_NAME = os.environ.get("TABLE_NAME")

def handler(event, context):
    """
    Accepts async jobs, writes status to DynamoDB, and sends to SQS.
    """
    body = json.loads(event.get("body", "{}"))
    action = body.get("action")
    job_id = str(uuid.uuid4())

    table = dynamodb.Table(TABLE_NAME)

    # Step 1: Save job status as 'pending'
    table.put_item(Item={
        "job_id": job_id,
        "user_id": body.get("user_id", "unknown"),
        "action": action,
        "status": "pending",
        "created_at": int(time.time())
    })

    # Step 2: Send message to SQS
    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps({
            "job_id": job_id,
            "action": action,
            "data": body
        })
    )

    # Step 3: Return accepted response
    return {
        "statusCode": 202,
        "body": json.dumps({
            "message": f"Async job accepted for '{action}'.",
            "job_id": job_id,
            "status": "pending"
        })
    }
