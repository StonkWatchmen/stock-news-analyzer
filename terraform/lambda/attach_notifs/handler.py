import json
import boto3
import os

sns = boto3.client("sns")

def handler(event, context):
    email = event.get('email')
    id = event.get('id')

    if email is None:
        return
    
    sns_arn = os.environ.get("NOTIFS_ARN")

    response = sns.subscribe(
        TopicArn = sns_arn,
        Protocol = "email",
        Endpoint = email,
        Atrributes = {
            "FilterPolicy": json.dumps({
                "userId" : [f"{id}"]
            })
        }
    )

    return response