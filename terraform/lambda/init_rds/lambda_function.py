import os
import pymysql

def get_connection():
    """Establish a connection to the RDS MySQL instance."""
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        port=int(os.environ.get("DB_PORT", 3306)),
        connect_timeout=5,
        autocommit=False,
        cursorclass=pymysql.cursors.DictCursor
    )

def execute_sql_file(conn, filepath):
    """Execute SQL commands from a file."""
    with open(filepath, "r") as file:
        sql_commands = file.read()

    # Split statements by semicolon and execute each
    with conn.cursor() as cur:
        for statement in sql_commands.split(";"):
            stmt = statement.strip()
            if stmt:
                cur.execute(stmt)
        conn.commit()

def lambda_handler(event, context):
    """Lambda entry point for database initialization."""
    print("Starting MySQL database initialization...")

    try:
        conn = get_connection()
        print("Connected to MySQL database.")

        sql_dir = os.path.join(os.path.dirname(__file__), "sql")

        # Example: Execute multiple SQL scripts in sequence
        for script in ["init_tables.sql", "seed_data.sql"]:
            filepath = os.path.join(sql_dir, script)
            if os.path.exists(filepath):
                print(f"Running {script}...")
                execute_sql_file(conn, filepath)
            else:
                print(f"Warning: {filepath} not found.")

        print("Database initialization complete.")
        return {"status": "success"}

    except Exception as e:
        print(f"Error initializing MySQL database: {e}")
        return {"status": "error", "message": str(e)}

    finally:
        if 'conn' in locals() and conn:
            conn.close()
            print("Connection closed.")
