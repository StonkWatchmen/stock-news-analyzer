import json
import boto3
import os
import pymysql

sns = boto3.client("sns")

def handler(event, context):
    
    
    
    sns_arn = os.environ.get("NOTIFS_ARN")

    response = sns.publish(
        TopicArn = sns_arn
        Protocol = "email"
        Endpoint = "email"
    )

    return event