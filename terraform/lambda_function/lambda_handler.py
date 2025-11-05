import os, json, base64
from datetime import datetime, timezone
import boto3
from botocore.exceptions import BotoCoreError, ClientError

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
    # Supports: API Gateway proxy (possibly base64) and direct invoke with dict
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

def _get_comprehend():
    use_comprehend = os.getenv("USE_COMPREHEND", "true").lower() == "true"
    if not use_comprehend:
        return None, False
    region = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "us-east-1"))
    return boto3.client("comprehend", region_name=region), True

def _analyze(text, comprehend, use_comprehend):
    if not (use_comprehend and comprehend and text and text.strip()):
        return {"sentiment": None, "scores": None, "entities": []}
    t = text[:4500]
    try:
        s = comprehend.detect_sentiment(Text=t, LanguageCode="en")
        e = comprehend.detect_entities(Text=t, LanguageCode="en")
        return {
            "sentiment": s.get("Sentiment"),
            "scores": s.get("SentimentScore"),
            "entities": [x.get("Text") for x in e.get("Entities", []) if x.get("Text")]
        }
    except (ClientError, BotoCoreError, Exception) as ce:
        print("Comprehend error:", repr(ce))
        return {"sentiment": None, "scores": None, "entities": []}

def lambda_handler(event, context):
    try:
        method = (event.get("requestContext", {}).get("http", {}).get("method")
                  or event.get("httpMethod") or "GET")

        # CORS preflight
        if method == "OPTIONS":
            return _resp(200, {"ok": True})

        if method == "GET":
            return _resp(200, {
                "ok": True,
                "message": "POST JSON to /analyze with {symbol,title,content}"
            })

        # No DynamoDB: we only optionally call Comprehend
        comprehend, use_comprehend = _get_comprehend()

        b = _parse_body(event)
        symbol  = (b.get("symbol") or "UNKNOWN").upper()
        title   = b.get("title")
        content = (b.get("content") or "").strip()

        if not content:
            return _resp(400, {"error": "content is required"})

        analysis = _analyze(content, comprehend, use_comprehend)

        # Return analysis; previously we wrote to DynamoDB.
        return _resp(201, {
            "ok": True,
            "symbol": symbol,
            "title": title,
            "sentiment": analysis["sentiment"],
            "scores": analysis["scores"],
            "entities": analysis["entities"],
            "analyzed_at": _now_iso()
        })

    except Exception as e:
        print("Unhandled error:", repr(e))
        return _resp(500, {"error": "internal_error"})
