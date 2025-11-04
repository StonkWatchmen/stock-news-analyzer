import os, json, base64, time
from datetime import datetime, timezone
import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
USE_COMPREHEND = os.getenv("USE_COMPREHEND", "true").lower() == "true"

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)
comprehend = boto3.client("comprehend") if USE_COMPREHEND else None

def _now_iso(): return datetime.now(timezone.utc).isoformat()

def _parse_body(event):
    body = event.get("body")
    if body is None: return {}
    if event.get("isBase64Encoded"): 
        import base64; body = base64.b64decode(body).decode("utf-8", "ignore")
    try: return json.loads(body)
    except: return {}

def _analyze(text):
    if not (USE_COMPREHEND and text and text.strip()):
        return {"sentiment": None, "scores": None, "entities": []}
    t = text[:4500]
    s = comprehend.detect_sentiment(Text=t, LanguageCode="en")
    e = comprehend.detect_entities(Text=t, LanguageCode="en")
    return {
        "sentiment": s.get("Sentiment"),
        "scores": s.get("SentimentScore"),
        "entities": [x.get("Text") for x in e.get("Entities", [])]
    }

def _resp(code, obj):
    return {"statusCode": code, "headers":{"Content-Type":"application/json"}, "body": json.dumps(obj)}

def lambda_handler(event, context):
    try:
        method = (event.get("requestContext", {}).get("http", {}).get("method")
                  or event.get("httpMethod") or "GET")
        if method == "GET":
            return _resp(200, {"ok": True, "message": "POST JSON to /analyze with {symbol,title,content}"})

        b = _parse_body(event)
        symbol  = (b.get("symbol") or "UNKNOWN").upper()
        title   = b.get("title")
        content = b.get("content") or ""

        if not content.strip():
            return _resp(400, {"error": "content is required"})

        a = _analyze(content)

        item = {
            "symbol": symbol,              # only the partition key if your table has no sort key
            "created_at": _now_iso(),      # harmless attribute even if not a key
            "title": title,
            "content": content[:2000],
            "sentiment": a["sentiment"],
            "sentiment_scores": a["scores"],
            "entities": a["entities"],
            "ts": int(time.time())
        }
        table.put_item(Item=item)
        return _resp(201, {"ok": True, "symbol": symbol, "sentiment": a["sentiment"], "entities": a["entities"]})

    except Exception as e:
        print("ERROR:", repr(e))
        return _resp(500, {"error": "internal_error"})
