import os
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

    user = event['userName'] 
    email = event['request']['userAttributes'].get('email')

    with conn.cursor() as cur:
        cur.execute("INSERT INTO users (id, email) VALUES (%s, %s)", (user, email))
        conn.commit()
    return event