import json
import boto3
import os

sns = boto3.client("sns")

def handler(event, context):
    email = event.get('message')

    if email is None:
        return
    
    sns_arn = os.environ.get("NOTIFS_ARN")

    response = sns.subscribe(
        TopicArn = sns_arn
        Protocol = "email"
        Endpoint = "email"
    )

    return event