import os
import json
try:
    import pymysql
except ImportError:
    pymysql = None
import urllib.request, urllib.parse
from decimal import Decimal
import boto3
import traceback
from datetime import datetime, timedelta, date

comprehend = boto3.client('comprehend')

DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASS = os.environ['DB_PASS']
DB_NAME = os.environ['DB_NAME']
ALPHA_VANTAGE_KEY = os.environ.get('ALPHA_VANTAGE_KEY')


# -------------------- Database Utilities --------------------
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
    """Get watchlist array from users table"""
    with conn.cursor() as cursor:
        cursor.execute("SELECT watchlist FROM users WHERE id = %s;", (user_id,))
        row = cursor.fetchone()
    if not row:
        return []
    watchlist = row.get("watchlist")
    if isinstance(watchlist, str):
        try:
            return json.loads(watchlist)
        except json.JSONDecodeError:
            return []
    return watchlist if isinstance(watchlist, list) else []


def add_to_watchlist(conn, user_id, ticker):
    """Add ticker to watchlist JSON array"""
    ticker = ticker.strip().upper()
    with conn.cursor() as cursor:
        cursor.execute("SELECT watchlist FROM users WHERE id = %s;", (user_id,))
        row = cursor.fetchone()
        if not row:
            return
        watchlist = row.get("watchlist", "[]")
        if isinstance(watchlist, str):
            watchlist = json.loads(watchlist)
        if ticker not in watchlist:
            watchlist.append(ticker)
            watchlist.sort()
            cursor.execute(
                "UPDATE users SET watchlist = %s WHERE id = %s;",
                (json.dumps(watchlist), user_id)
            )
            conn.commit()


def remove_from_watchlist(conn, user_id, ticker):
    """Remove ticker from watchlist JSON array"""
    ticker = ticker.strip().upper()
    with conn.cursor() as cursor:
        cursor.execute("SELECT watchlist FROM users WHERE id = %s;", (user_id,))
        row = cursor.fetchone()
        if not row:
            return
        watchlist = row.get("watchlist", "[]")
        if isinstance(watchlist, str):
            watchlist = json.loads(watchlist)
        if ticker in watchlist:
            watchlist.remove(ticker)
            cursor.execute(
                "UPDATE users SET watchlist = %s WHERE id = %s;",
                (json.dumps(watchlist), user_id)
            )
            conn.commit()


# -------------------- Stock History --------------------
def get_stock_history(conn, stock_id=None, ticker=None, time_range="24h"):
    now = datetime.utcnow()
    time_ranges = {
        '24h': now - timedelta(hours=24),
        '7d': now - timedelta(days=7),
        '30d': now - timedelta(days=30),
        '90d': now - timedelta(days=90),
        '1y': now - timedelta(days=365),
        'all': datetime(2000, 1, 1)
    }
    start_time = time_ranges.get(time_range, time_ranges['24h'])

    if time_range == '24h':
        interval_sql = "DATE_FORMAT(recorded_at, '%Y-%m-%d %H:00:00')"
    elif time_range in ['7d', '30d']:
        interval_sql = "DATE(recorded_at)"
    elif time_range == '90d':
        interval_sql = "DATE_FORMAT(recorded_at, '%Y-%U')"
    else:
        interval_sql = "DATE_FORMAT(recorded_at, '%Y-%m-01')"

    with conn.cursor() as cursor:
        if stock_id:
            cursor.execute(f"""
                SELECT s.ticker, {interval_sql} as time_bucket,
                       AVG(sh.price) as avg_price,
                       AVG(sh.avg_sentiment) as avg_sentiment,
                       MAX(sh.recorded_at) as latest_time
                FROM stock_history sh
                JOIN stocks s ON sh.stock_id = s.id
                WHERE sh.stock_id = %s AND sh.recorded_at >= %s AND sh.recorded_at <= %s
                GROUP BY s.ticker, time_bucket
                ORDER BY time_bucket ASC
            """, (stock_id, start_time, now))
        elif ticker:
            cursor.execute(f"""
                SELECT s.ticker, {interval_sql} as time_bucket,
                       AVG(sh.price) as avg_price,
                       AVG(sh.avg_sentiment) as avg_sentiment,
                       MAX(sh.recorded_at) as latest_time
                FROM stock_history sh
                JOIN stocks s ON sh.stock_id = s.id
                WHERE s.ticker = %s AND sh.recorded_at >= %s AND sh.recorded_at <= %s
                GROUP BY s.ticker, time_bucket
                ORDER BY time_bucket ASC
            """, (ticker.upper(), start_time, now))
        else:
            return []

        rows = cursor.fetchall()
        results = []
        for row in rows:
            results.append({
                'ticker': row['ticker'],
                'price': float(row['avg_price']) if row['avg_price'] else None,
                'avg_sentiment': float(row['avg_sentiment']) if row['avg_sentiment'] else None,
                'recorded_at': row['latest_time'].isoformat() if row['latest_time'] else None
            })
        return results


# -------------------- JSON & HTTP Utilities --------------------
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


def _http_get_json(url):
    with urllib.request.urlopen(url, timeout=8) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _fetch_alpha_vantage_news_sentiment(symbol: str):
    if not ALPHA_VANTAGE_KEY:
        return {"ticker": symbol, "error": "Missing ALPHA_VANTAGE_KEY"}

    base = "https://www.alphavantage.co/query"
    qs = urllib.parse.urlencode({
        "function": "NEWS_SENTIMENT",
        "tickers": symbol,
        "apikey": ALPHA_VANTAGE_KEY,
    })
    url = f"{base}?{qs}"

    try:
        data = _http_get_json(url)
    except Exception as e:
        return {"ticker": symbol, "error": f"HTTP error: {e}"}

    feed = data.get("feed", [])
    if not feed:
        return {"ticker": symbol, "sentiment_score": None, "sentiment_label": None, "error": "No sentiment data"}

    overall_score = data.get("overall_sentiment_score")
    overall_label = data.get("overall_sentiment_label")

    if overall_score is None:
        scores = []
        for article in feed:
            for ts in article.get("ticker_sentiment", []):
                if ts.get("ticker") == symbol:
                    try:
                        scores.append(float(ts.get("ticker_sentiment_score", 0)))
                    except ValueError:
                        continue
        if scores:
            overall_score = sum(scores) / len(scores)
            if overall_score <= -0.35:
                overall_label = "Bearish"
            elif overall_score < -0.15:
                overall_label = "Somewhat-Bearish"
            elif overall_score < 0.15:
                overall_label = "Neutral"
            elif overall_score < 0.35:
                overall_label = "Somewhat-Bullish"
            else:
                overall_label = "Bullish"

    return {"ticker": symbol, "sentiment_score": overall_score, "sentiment_label": overall_label, "error": None}


def _fetch_news_sentiment_for_tickers(tickers):
    out = []
    for t in tickers:
        t = t.strip().upper()
        if not t:
            continue
        out.append(_fetch_alpha_vantage_news_sentiment(t))
    return out


# -------------------- Lambda Handler --------------------
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
            qs = event.get("queryStringParameters") or {}
            body = {}
            if event.get("body"):
                try:
                    body = json.loads(event["body"])
                except json.JSONDecodeError:
                    body = {}

            # GET /stocks
            if path.endswith("/stocks") and method == "GET":
                rows = list_stocks(conn)
                return _resp(200, {"stocks": rows})

            # GET /watchlist
            if path.endswith("/watchlist") and method == "GET":
                user_id = qs.get("user_id")
                if not user_id:
                    return _resp(400, {"error": "user_id is required"})
                tickers = get_watchlist(conn, int(user_id))
                return _resp(200, {"user_id": int(user_id), "tickers": tickers})

            # GET /stock-history
            if path.endswith("/stock-history") and method == "GET":
                stock_id = qs.get("stock_id")
                ticker = qs.get("ticker")
                time_range = qs.get("range", "24h")
                if not stock_id and not ticker:
                    return _resp(400, {"error": "stock_id or ticker is required"})
                history = get_stock_history(
                    conn,
                    stock_id=int(stock_id) if stock_id else None,
                    ticker=ticker,
                    time_range=time_range
                )
                return _resp(200, {"ticker": ticker.upper() if ticker else None,
                                   "time_range": time_range,
                                   "history": history,
                                   "count": len(history)})

            # GET /quotes
            if path.endswith("/quotes") and method == "GET":
                tickers = [t.strip().upper() for t in (qs.get("tickers", "").split(",")) if t.strip()]
                if not tickers:
                    return _resp(400, {"error": "tickers query param required"})
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

            # POST /watchlist
            if path.endswith("/watchlist") and method == "POST":
                user_id = body.get("user_id")
                ticker = body.get("ticker")
                if not user_id or not ticker:
                    return _resp(400, {"error": "user_id and ticker are required"})
                add_to_watchlist(conn, int(user_id), ticker)
                return _resp(200, {"message": "added", "ticker": ticker})

            # DELETE /watchlist
            if path.endswith("/watchlist") and method == "DELETE":
                user_id = body.get("user_id")
                ticker = body.get("ticker")
                if not user_id or not ticker:
                    return _resp(400, {"error": "user_id and ticker are required"})
                remove_from_watchlist(conn, int(user_id), ticker)
                return _resp(200, {"message": "removed", "ticker": ticker})

            return _resp(404, {"error": "not found", "path": path, "method": method})

        except Exception as e:
            return _resp(500, {"error": str(e)})

        finally:
            if conn:
                conn.close()

    except Exception:
        return _resp(500, {"error": "Unhandled exception", "trace": traceback.format_exc()})