import os, json, base64, time
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
    """
    Supports:
      - API Gateway proxy: {"body": "...", "isBase64Encoded": bool}
      - Direct invoke: the payload dict itself
    """
    if isinstance(event, dict) and "body" not in event:
        return event  # direct invoke with a dict payload

    body = event.get("body")
    if body is None:
        return {}
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8", "ignore")
    try:
        return json.loads(body)
    except Exception:
        return {}

def _get_clients():
    table_name = os.getenv("TABLE_NAME")
    if not table_name:
        raise RuntimeError("Missing TABLE_NAME environment variable")
    use_comprehend = os.getenv("USE_COMPREHEND", "true").lower() == "true"
    region = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "us-east-1"))

    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(table_name)
    comprehend = None
    if use_comprehend:
        comprehend = boto3.client("comprehend", region_name=region)
    return table, comprehend, use_comprehend

def _analyze(text, comprehend, use_comprehend):
    if not (use_comprehend and comprehend and text and text.strip()):
        return {"sentiment": None, "scores": None, "entities": []}

    t = text[:4500]  # keep well under Comprehend limits
    try:
        s = comprehend.detect_sentiment(Text=t, LanguageCode="en")
        e = comprehend.detect_entities(Text=t, LanguageCode="en")
        return {
            "sentiment": s.get("Sentiment"),
            "scores": s.get("SentimentScore"),
            "entities": [x.get("Text") for x in e.get("Entities", []) if x.get("Text")]
        }
    except (ClientError, BotoCoreError, Exception) as ce:
        # Log but don't fail the request
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
            return _resp(200, {"ok": True, "message": "POST JSON to /analyze with {symbol,title,content}"})

        table, comprehend, use_comprehend = _get_clients()

        b = _parse_body(event)
        symbol  = (b.get("symbol") or "UNKNOWN").upper()
        title   = b.get("title")
        content = (b.get("content") or "").strip()

        if not content:
            return _resp(400, {"error": "content is required"})

        analysis = _analyze(content, comprehend, use_comprehend)

        item = {
            # DynamoDB keys — must match your schema
            "symbol": symbol,            # PK (S)
            "created_at": _now_iso(),    # SK (S)

            # Attributes
            "title": title,
            "content": content[:2000],
            "sentiment": analysis["sentiment"],
            "sentiment_scores": analysis["scores"],
            "entities": analysis["entities"],
            "ts": int(time.time())
        }

        table.put_item(Item=item)

        return _resp(201, {
            "ok": True,
            "symbol": symbol,
            "sentiment": analysis["sentiment"],
            "entities": analysis["entities"]
        })

    except (ClientError, BotoCoreError) as aws_err:
        # Useful error surface when IAM/table issues occur
        print("AWS client error:", repr(aws_err))
        return _resp(500, {"error": "aws_client_error"})
    except Exception as e:
        print("Unhandled error:", repr(e))
        return _resp(500, {"error": "internal_error"})
