import os, json, base64, time
from datetime import datetime, timezone
import pymysql

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
    "Content-Type": "application/json"
}

def _now_iso():
    return datetime.now(timezone.utc).isoformat()

def _resp(code, obj):
    return {"statusCode": code, "headers": CORS_HEADERS, "body": json.dumps(obj)}

def _parse_body(event):
    # Supports both API Gateway and direct test invocation
    if isinstance(event, dict) and "body" not in event:
        return event
    body = event.get("body")
    if body is None:
        return {}
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8", "ignore")
    try:
        return json.loads(body)
    except Exception:
        return {}

def _get_conn():
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ["DB_NAME"],
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
    )

_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS news_analysis (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  symbol VARCHAR(16) NOT NULL,
  created_at TIMESTAMP NOT NULL,
  title VARCHAR(255) NULL,
  content TEXT NOT NULL,
  sentiment VARCHAR(16) NULL,
  sentiment_pos DECIMAL(10,6) NULL,
  sentiment_neg DECIMAL(10,6) NULL,
  sentiment_neu DECIMAL(10,6) NULL,
  sentiment_mix DECIMAL(10,6) NULL,
  entities TEXT NULL,
  ts BIGINT NOT NULL,
  INDEX idx_symbol_created (symbol, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"""

def _ensure_schema(conn):
    with conn.cursor() as cur:
        cur.execute(_SCHEMA_SQL)

def _analyze(text):
    # Stub for now—plug Comprehend back in later if desired
    return {"sentiment": None, "scores": None, "entities": []}

def lambda_handler(event, context):
    method = (event.get("requestContext", {}).get("http", {}).get("method")
              or event.get("httpMethod") or "GET")

    if method == "OPTIONS":
        return _resp(200, {"ok": True})

    if method == "GET":
        return _resp(200, {"ok": True, "message": "POST JSON to /analyze with {symbol,title,content}"})

    b = _parse_body(event)
    symbol  = (b.get("symbol") or "UNKNOWN").upper()
    title   = b.get("title")
    content = (b.get("content") or "").strip()
    if not content:
        return _resp(400, {"error": "content is required"})

    analysis = _analyze(content)
    created  = _now_iso()
    ts       = int(time.time())

    sp = sn = sneu = smix = None
    if isinstance(analysis.get("scores"), dict):
        sp   = analysis["scores"].get("Positive")
        sn   = analysis["scores"].get("Negative")
        sneu = analysis["scores"].get("Neutral")
        smix = analysis["scores"].get("Mixed")

    entities = ",".join(analysis.get("entities") or [])

    try:
        conn = _get_conn()
        _ensure_schema(conn)
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO news_analysis
                  (symbol, created_at, title, content, sentiment,
                   sentiment_pos, sentiment_neg, sentiment_neu, sentiment_mix,
                   entities, ts)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (symbol, created, title, content[:2000], analysis["sentiment"],
                 sp, sn, sneu, smix, entities, ts)
            )
        conn.close()
    except Exception as e:
        print("DB error:", repr(e))
        return _resp(500, {"error": "db_error"})

    return _resp(201, {
        "ok": True,
        "symbol": symbol,
        "sentiment": analysis["sentiment"],
        "entities": analysis.get("entities", [])
    })
