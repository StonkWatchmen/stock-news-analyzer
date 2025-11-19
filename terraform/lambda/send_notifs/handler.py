import json
import boto3
import os
import pymysql

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
    sns_arn = os.environ.get("NOTIFS_ARN")

    conn = get_connection()

    with conn.cursor() as cur:
        cur.execute("SELECT id,email,watchlist FROM users;")
        all_user_info = cur.fetchall()

        for info in all_user_info:
            key = (stock_index for stock_index in info["watchlist"])
            cur.execute(f"""
                            SELECT sh.avg_sentiment
                            FROM stock_history sh
                            JOIN (
                                SELECT stock_id, MAX(recorded_at) AS max_time
                                FROM stock_history
                                GROUP BY stock_id
                            ) latest
                            ON latest.stock_id = sh.stock_id
                            AND latest.max_time = sh.recorded_at
                            WHERE sh.stock_id IN {key};
                        """)

            response = sns.publish(
                TopicArn = sns_arn,
                subject = f"Hourly Stock Market Update",
                # mesasge = put somthing
                messageAttributes = {
                    "userId": {
                        "DataType": "String",
                        "StringValue": f"{info['id']}"
                    }
                }
            )

    return response