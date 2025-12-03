import json
import boto3
import os
import pymysql

ses = boto3.client("ses")

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
    dev_email = os.environ.get("DEV_EMAIL")

    conn = get_connection()

    with conn.cursor() as cur:
        cur.execute("SELECT id,email FROM users;")
        all_user_info = cur.fetchall()

        for user in all_user_info:
            email = user["email"]

            message_text = (
                f"Hello {email},\n\n"
                "Here is your personalized notification.\n"
            )

            response = ses.send_email(
                Source=dev_email,
                Destination={"ToAddresses": [email]},
                Message={
                    "Subject": {"Data": f"Your personalized stock updates"},
                    "Body": {"Text": {"Data": message_text}}
                }
            )


    return response