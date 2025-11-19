import json
import boto3
import pymysql
import os

sns = boto3.client("sns")

def get_connection():
    """Establish a connection to the RDS MySQL instance."""
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ["DB_NAME"],
        port=int(os.environ.get("DB_PORT", 3306)),
        connect_timeout=5,
        autocommit=False,
        cursorclass=pymysql.cursors.DictCursor
    )

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