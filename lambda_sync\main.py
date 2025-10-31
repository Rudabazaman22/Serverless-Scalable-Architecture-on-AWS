import json

def handler(event, context):
    """
    Handles synchronous requests instantly (no queue or DB).
    """
    body = json.loads(event.get("body", "{}"))
    action = body.get("action")

    if action == "login":
        response = {"message": f"User {body.get('username')} logged in successfully."}
        status_code = 200
    elif action == "check_subscription":
        response = {"message": f"Subscription {body.get('subscription_id')} is active."}
        status_code = 200
    else:
        response = {"error": "Unknown synchronous action."}
        status_code = 400  # Bad Request

    return {
        "statusCode": status_code,
        "body": json.dumps(response)
        }
