import os
import json
import pymysql

DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASS = os.environ['DB_PASS']
DB_NAME = os.environ['DB_NAME']

def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        connect_timeout=5
    )

def lambda_handler(event, context):
    """
    Handles API Gateway requests and returns a JSON response.
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM stocks;")
            result = cursor.fetchall()

        conn.close()

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "DB connection successful",
                "stocks": result
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }
