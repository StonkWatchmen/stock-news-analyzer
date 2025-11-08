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
    
def _resp(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
            "Access-Control-Allow_Headers": "Content-Type",            
        },
        "body": json.dumps(body),
    } 

def list_stocks(conn):
    with conn.cursor() as cursor:
        cursor.execute("SELECT id, ticker FROM stocks ORDER BY ticker;")
        return cursor.fetchall()

def get_watchlist(conn, user_id):
    with conn.cursor() as cursor:
        cursor.execute(
            """
            SELECT s.ticker
            FROM watchlist w
            JOIN stocks s ON w.stock_id = s.id
            WHERE w.user_id = %s;
            ORDER BY s.ticker;
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
    return [r["ticker"] for r in rows]

def ensure_stock(conn, ticker):
    with conn.cursor() as cursor:
        cursor.execute("SELECT id FROM stocks WHERE ticker = %s;", (ticker,))
        row = cursor.fetchone()
        if row:
            return row["id"]
        
        cursor.execute("INSERT INTO stocks(ticker) VALUES (%s);", (ticker,))
        conn.commit()
        return cursor.lastrowid

def add_to_watchlist(conn, user_id, ticker):
    stock_id = ensure_stock(conn, ticker)
    with conn.cursor() as cursor:
        cursor.execute(
            "SELECT id FROM watchlist WHERE user_id = %s AND stock_id = %s;",
            (user_id, stock_id),
        )
        row = cursor.fetchone()
        if row:
            return
        cursor.execute(
            "INSERT INTO watchlist(user_id, stock_id) VALUES (%s, %s);",
            (user_id, stock_id),
        )        
    conn.commit()

def remove_from_watchlist(conn, user_id, ticker):
    with conn.cursor() as cursor:
        cursor.execute("SELECT id FROM stocks WHERE ticker = %s;", (ticker,))        
        row = cursor.fetchone()
        if row:
            return
        stock_id = row["id"]
        cursor.execute(
            "DELETE FROM watchlist WHERE user_id = %s AND stock_id = %s;",
            (user_id, stock_id),
        )        
    conn.commit()         
       

def lambda_handler(event, context):
    # """
    # Handles API Gateway requests and returns a JSON response.
    # """
    # try:
    #     conn = get_db_connection()
    #     with conn.cursor() as cursor:
    #         cursor.execute("SELECT * FROM stocks;")
    #         result = cursor.fetchall()

    #     conn.close()

    #     return {
    #         "statusCode": 200,
    #         "body": json.dumps({
    #             "message": "DB connection successful",
    #             "stocks": result
    #         })
    #     }

    # except Exception as e:
    #     return {
    #         "statusCode": 500,
    #         "body": json.dumps({
    #             "error": str(e)
    #         })
    #     }
    
    if event.get("httpMethod") == "OPTIONS":
        return _resp(200, {"ok": True})
    
    path = event.get("path", "/")
    method = event.get("httpMethod", "GET")
        
    try:
        conn = get_db_connection()
    except Exception as e:
        return _resp(500, {f"DB connection failed: {str(e)}"})
    
    try:
        # GET /stocks
        if path.endswith("/stocks") and method == "GET":
            rows = list_stocks(conn)
            conn.close()
            return _resp(200, {"stocks": rows})
        
        # GET /watchlist?user_id=1
        if path.endswith("/watchlist") and method == "GET":
            qs = event.get("queryStringParameters") or {}
            user_id = qs.get("user_id")
            if not user_id:
                conn.close()
                return _resp(400, {"error": "user_id is required"})
            tickers = get_watchlist(conn, user_id)
            conn.close()
            return _resp(200, {"user_id": int(user_id), "tickers": tickers})
        
        # body for POST/DELETE
        body = {}
        if event.get("body"):
            try:
                body = json.loads(event["body"])
            except json.JSONDecodeError:
                body = {}
        
        # POST /watchlist
        if path.endswith("/watchlist") and method == "POST":
            user_id = body.get("user_id")
            ticker = body.get("ticker")
            if not user_id or not ticker:
                conn.close()
                return _resp(400, {"error": "user_id and ticker are required"})
            ticker = ticker.strip().upper()
            add_to_watchlist(conn, int(user_id), ticker)
            conn.close()
            return _resp(200, {"message": "added", "ticker": ticker})
        
        # DELETE /watchlist
        if path.endswith("/watchlist") and method == "DELETE":
            user_id = body.get("user_id")
            ticker = body.get("ticker")
            if not user_id or not ticker:
                conn.close()
                return _resp(400, {"error": "user_id and ticker are required"})
            ticker = ticker.strip().upper()
            remove_from_watchlist(conn, int(user_id), ticker)
            conn.close()
            return _resp(200, {"message": "removed", "ticker": ticker})
        
        conn.close()
        return _resp(404, {"error": "not found", "path": path, "method": method})             
    
    except Exception as e:
        conn.close()
        return _resp(500, {"error": str(e)})    
                 
