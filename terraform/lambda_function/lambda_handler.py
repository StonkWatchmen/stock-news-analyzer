import os
import json
import base64
import time
from datetime import datetime, timezone

import pymysql


_BOTO3 = None

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "OPTIONS,GET,POST",
    "Content-Type": "application/json",
}

# ---------- helpers ----------
def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def _resp(code: int, obj) -> dict:
    return {"statusCode": code, "headers": CORS_HEADERS, "body": json.dumps(obj)}

def _parse_body(event: dict) -> dict:
    # Accept both direct test events and API Gateway v2 events
    if isinstance(event, dict) and "body" not in event:
        return event
    body = event.get("body")
    if body is None:
        return {}
    if event.get("isBase64Encoded"):
        try:
            body = base64.b64decode(body).decode("utf-8", "ignore")
        except Exception:
            pass
    try:
        return json.loads(body)
    except Exception:
        return {}

def _use_comprehend() -> bool:
    return os.environ.get("USE_COMPREHEND", "false").lower() == "true"

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

def _ensure_schema(conn) -> None:
    with conn.cursor() as cur:
        cur.execute(_SCHEMA_SQL)

def _analyze(text: str):
    """
    Returns dict: { sentiment: str|None, scores: {Positive,Negative,Neutral,Mixed}|None, entities: [str] }
    Uses Comprehend only if USE_COMPREHEND=true. Falls back gracefully if not reachable.
    """
    if not _use_comprehend():
        return {"sentiment": None, "scores": None, "entities": []}

    global _BOTO3
    if _BOTO3 is None:
        import boto3 as _BOTO3  # lazy import (available in Lambda runtime)

    try:
        comp = _BOTO3.client("comprehend")
        det = comp.detect_sentiment(Text=text[:4500], LanguageCode="en")
        ent = comp.detect_entities(Text=text[:4500], LanguageCode="en")
        sentiment = det.get("Sentiment")
        scores = det.get("SentimentScore") or {}
        entities = [e["Text"] for e in ent.get("Entities", []) if e.get("Text")]
        return {"sentiment": sentiment, "scores": scores, "entities": entities}
    except Exception as e:
        # In private subnets without NAT/VPC endpoints, external calls may fail; fall back silently.
        print("Comprehend error:", repr(e))
        return {"sentiment": None, "scores": None, "entities": []}

# ---------- handler ----------
def lambda_handler(event, context):
    # API Gateway HTTP API (v2) fields
    method = (event.get("requestContext", {}).get("http", {}).get("method")
              or event.get("httpMethod") or "GET")
    raw_path = (event.get("requestContext", {}).get("http", {}).get("path")
                or event.get("rawPath") or "/")
    qs = event.get("queryStringParameters") or {}

    # CORS preflight
    if method == "OPTIONS":
        return _resp(200, {"ok": True})

    # GET "/" 
    if method == "GET":
        limit = 10
        try:
            if "limit" in qs:
                limit = max(1, min(100, int(qs["limit"])))
        except Exception:
            limit = 10

        symbol = qs.get("symbol")
        try:
            conn = _get_conn()
            _ensure_schema(conn)
            with conn.cursor() as cur:
                if symbol:
                    cur.execute(
                        """
                        SELECT id, symbol, created_at, title, sentiment
                        FROM news_analysis
                        WHERE symbol = %s
                        ORDER BY id DESC
                        LIMIT %s
                        """,
                        (symbol.upper(), limit),
                    )
                else:
                    cur.execute(
                        """
                        SELECT id, symbol, created_at, title, sentiment
                        FROM news_analysis
                        ORDER BY id DESC
                        LIMIT %s
                        """,
                        (limit,),
                    )
                rows = cur.fetchall()
            conn.close()
            return _resp(200, {"ok": True, "count": len(rows), "records": rows})
        except Exception as e:
            print("DB read error:", repr(e))
            return _resp(500, {"error": "db_read_failed"})

    # POST "/analyze"
    if method == "POST":
        body = _parse_body(event)
        symbol = (body.get("symbol") or "UNKNOWN").upper()
        title = body.get("title")
        content = (body.get("content") or "").strip()
        if not content:
            return _resp(400, {"error": "content is required"})

        analysis = _analyze(content)
        created = _now_iso()
        ts = int(time.time())

        sp = sn = sneu = smix = None
        if isinstance(analysis.get("scores"), dict):
            sp = analysis["scores"].get("Positive")
            sn = analysis["scores"].get("Negative")
            sneu = analysis["scores"].get("Neutral")
            smix = analysis["scores"].get("Mixed")

        entities_csv = ",".join(analysis.get("entities") or [])

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
                    (
                        symbol,
                        created,
                        title,
                        content[:2000],
                        analysis["sentiment"],
                        sp,
                        sn,
                        sneu,
                        smix,
                        entities_csv,
                        ts,
                    ),
                )
            conn.close()
        except Exception as e:
            print("DB write error:", repr(e))
            return _resp(500, {"error": "db_write_failed"})

        return _resp(
            201,
            {
                "ok": True,
                "symbol": symbol,
                "sentiment": analysis["sentiment"],
                "entities": analysis.get("entities", []),
            },
        )

    # Any other method -> not allowed
    return _resp(405, {"error": "method_not_allowed"})
