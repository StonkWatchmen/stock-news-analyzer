import os
import json
import pymysql
import urllib.request, urllib.parse
from decimal import Decimal
from datetime import datetime, date
import boto3
import traceback  # <--- added for debugging unexpected errors
try:
    import pymysql
except ImportError:
    pymysql = None


comprehend = boto3.client('comprehend')
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASS = os.environ['DB_PASS']
DB_NAME = os.environ['DB_NAME']
ALPHA_VANTAGE_KEY = os.environ.get('ALPHA_VANTAGE_KEY')  


# Custom JSON encoder to handle Decimal and datetime objects
class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        return super().default(obj)

def _resp(status, body):
    return {
        "isBase64Encoded": False,
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",            
        },
        "body": json.dumps(body, cls=CustomJSONEncoder),
    } 


def get_db_connection():
    if pymysql is None:
        raise RuntimeError("pymysql not installed in lambda package")

    missing = [
        name for name, val in [
            ("DB_HOST", DB_HOST),
            ("DB_USER", DB_USER),
            ("DB_PASS", DB_PASS),
            ("DB_NAME", DB_NAME),
        ] if not val
    ]
    if missing:
        raise RuntimeError(f"Missing DB env vars: {', '.join(missing)}")

    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
    )

def list_stocks(conn):
    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM stocks ORDER BY ticker;")
        return cursor.fetchall()

def get_watchlist(conn, user_id):
    with conn.cursor() as cursor:
        cursor.execute(
            """
            SELECT s.ticker
            FROM watchlist w
            JOIN stocks s ON w.stock_id = s.id
            WHERE w.user_id = %s
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
        if not row:
            return
        stock_id = row["id"]
        cursor.execute(
            "DELETE FROM watchlist WHERE user_id = %s AND stock_id = %s;",
            (user_id, stock_id),
        )        
    conn.commit()         
       

def _http_get_json(url):
    with urllib.request.urlopen(url, timeout=8) as resp:
        return json.loads(resp.read().decode("utf-8"))


# def _fetch_alpha_vantage_quote(symbol: str):
#     if not ALPHA_VANTAGE_KEY:
#         return {"ticker": symbol, "error": "Missing ALPHA_VANTAGE_KEY"}
#     base = "https://www.alphavantage.co/query"
#     qs = urllib.parse.urlencode(
#         {"function": "GLOBAL_QUOTE", "symbol": symbol, "apikey": ALPHA_VANTAGE_KEY}
#     )
#     data = _http_get_json(f"{base}?{qs}")
#     q = data.get("Global Quote", {})
#     if not q:
#         return {"ticker": symbol, "error": "No quote"}
#     try:
#         price = float(Decimal(q.get("05. price", "0")))
#     except Exception:
#         price = None
#     chg_pct_raw = (q.get("10. change percent") or "0").replace("%", "")
#     try:
#         change_pct = float(Decimal(chg_pct_raw))
#     except Exception:
#         change_pct = None
#     return {"ticker": symbol, "price": price, "change_pct": change_pct}


def _fetch_alpha_vantage_news_sentiment(symbol: str):
    if not ALPHA_VANTAGE_KEY:
        return {"ticker": symbol, "error": "Missing ALPHA_VANTAGE_KEY"}

    base = "https://www.alphavantage.co/query"
    qs = urllib.parse.urlencode(
        {
            "function": "NEWS_SENTIMENT",
            "tickers": symbol,
            "apikey": ALPHA_VANTAGE_KEY,
        }
    )
    try:
        data = _http_get_json(f"{base}?{qs}")
    except Exception as e:
        return {"ticker": symbol, "error": f"HTTP error: {e}"}

    feed = data.get("feed", [])
    if not feed:
        return {"ticker": symbol, "sentiment_score": None, "sentiment_label": None}

    scores = []

    for article in feed:
        for ts in article.get("ticker_sentiment", []):
            if ts.get("ticker") == symbol:
                try:
                    scores.append(float(ts.get("ticker_sentiment_score", 0.0)))
                except Exception:
                    continue

    if not scores:
        for article in feed:
            try:
                s = float(article.get("overall_sentiment_score", 0.0))
                scores.append(s)
            except Exception:
                continue

    if not scores:
        return {"ticker": symbol, "sentiment_score": None, "sentiment_label": None}

    avg = sum(scores) / len(scores)

    if avg <= -0.35:
        label = "Bearish"
    elif avg < -0.15:
        label = "Somewhat-Bearish"
    elif avg < 0.15:
        label = "Neutral"
    elif avg < 0.35:
        label = "Somewhat-Bullish"
    else:
        label = "Bullish"

    return {
        "ticker": symbol,
        "sentiment_score": avg,
        "sentiment_label": label,
    }


def _fetch_news_sentiment_for_tickers(tickers):
    out = []
    for t in tickers:
        t = t.strip().upper()
        if not t:
            continue
        out.append(_fetch_alpha_vantage_news_sentiment(t))
    return out


# def _fetch_quotes_live(tickers):
#     out = []
#     for t in tickers:
#         t = t.strip().upper()
#         if not t:
#             continue
#         out.append(_fetch_alpha_vantage_quote(t))
#     return out


# def _upsert_prices(conn, quotes):
#     if not quotes:
#         return
#     with conn.cursor() as c:
#         for q in quotes:
#             if "price" not in q or q.get("price") is None:
#                 continue
#             c.execute("SELECT id FROM stocks WHERE ticker=%s", (q["ticker"],))
#             r = c.fetchone()
#             if not r:
#                 c.execute("INSERT INTO stocks(ticker) VALUES (%s)", (q["ticker"],))
#                 stock_id = c.lastrowid
#             else:
#                 stock_id = r["id"]
#             c.execute("""
#                 INSERT INTO prices(stock_id, price, change_pct)
#                 VALUES (%s,%s,%s)
#                 ON DUPLICATE KEY UPDATE price=VALUES(price), change_pct=VALUES(change_pct)
#             """, (stock_id, q["price"], q.get("change_pct")))
#     conn.commit()

# def _get_cached_quotes(conn, tickers):
#     if not tickers:
#         return []
#     fmt = ",".join(["%s"] * len(tickers))
#     with conn.cursor() as c:
#         c.execute(f"""
#             SELECT s.ticker, p.price, p.change_pct, p.updated_at
#             FROM stocks s
#             JOIN prices p ON p.stock_id = s.id
#             WHERE s.ticker IN ({fmt})
#         """, tuple(t.upper() for t in tickers))
#         rows = c.fetchall()
#     return [
#         {
#             "ticker": r["ticker"],
#             "price": float(r["price"]) if r["price"] is not None else None,
#             "change_pct": float(r["change_pct"]) if r["change_pct"] is not None else None,
#             "updated_at": r["updated_at"].isoformat() if r.get("updated_at") else None
#         }
#         for r in rows
#     ]


def lambda_handler(event, context):
    try:
        if event.get("httpMethod") == "OPTIONS":
            return _resp(200, {"ok": True})

        path = event.get("path", "/")
        method = event.get("httpMethod", "GET")

        conn = None
        try:
            conn = get_db_connection()
        except Exception as e:
            return _resp(500, {"error": f"DB connection failed: {str(e)}"})

        try:
            # GET /stocks
            if path.endswith("/stocks") and method == "GET":
                rows = list_stocks(conn)
                return _resp(200, {"stocks": rows})

            # GET /watchlist?user_id=1
            if path.endswith("/watchlist") and method == "GET":
                qs = event.get("queryStringParameters") or {}
                user_id = qs.get("user_id")
                if not user_id:
                    return _resp(400, {"error": "user_id is required"})
                tickers = get_watchlist(conn, user_id)
                return _resp(200, {"user_id": int(user_id), "tickers": tickers})

            # GET /quotes?tickers=AAPL,MSFT
            if path.endswith("/quotes") and method == "GET":
                qs = event.get("queryStringParameters") or {}
                tickers = [
                    t.strip().upper()
                    for t in (qs.get("tickers", "").split(","))
                    if t.strip()
                ]
                if not tickers:
                    return _resp(
                        400,
                        {"error": "tickers query param required, e.g. ?tickers=AAPL,MSFT"},
                    )

                # Only fetch sentiment – no DB reads/writes, no `prices` table
                sentiments = _fetch_news_sentiment_for_tickers(tickers)
                sentiments_map = {s["ticker"]: s for s in sentiments}

                quotes = []
                for ticker in tickers:
                    s = sentiments_map.get(ticker, {}) or {}
                    quotes.append({
                        "ticker": ticker,
                        "price": None,
                        "change_pct": None,
                        "sentiment_score": s.get("sentiment_score"),
                        "sentiment_label": s.get("sentiment_label"),
                        "error": s.get("error"),
                    })

                return _resp(200, {"quotes": quotes})
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
                    return _resp(400, {"error": "user_id and ticker are required"})
                ticker = ticker.strip().upper()
                add_to_watchlist(conn, int(user_id), ticker)
                return _resp(200, {"message": "added", "ticker": ticker})
            
            # DELETE /watchlist
            if path.endswith("/watchlist") and method == "DELETE":
                user_id = body.get("user_id")
                ticker = body.get("ticker")
                if not user_id or not ticker:
                    return _resp(400, {"error": "user_id and ticker are required"})
                ticker = ticker.strip().upper()
                remove_from_watchlist(conn, int(user_id), ticker)
                return _resp(200, {"message": "removed", "ticker": ticker})
            
            return _resp(404, {"error": "not found", "path": path, "method": method})             
        
        except Exception as e:
            return _resp(500, {"error": str(e)})
        
        finally:
            if conn:
                conn.close()

    except Exception as e:
        # Catch any unexpected error and ensure valid Lambda proxy response
        return _resp(500, {"error": "Unhandled exception", "trace": traceback.format_exc()})
