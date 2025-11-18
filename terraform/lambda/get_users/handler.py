import os
import json
import pymysql

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

def lambda_handler(event, context):
  conn = get_connection()

  with conn.cursor() as cur:
    cur.execute("SELECT * FROM users;")
    rows = cur.fetchall()

  conn.close()

  return {
    "statusCode": 200,
    "body": json.dumps(rows, default=str)
  }