import os
import json
import time
from datetime import datetime, timezone
import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
REGION     = os.getenv("AWS_REGION", "us-east-1")
USE_COMPREHEND = os.getenv("USE_COMPREHEND", "true").lower() == "true"

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table    = dynamodb.Table(TABLE_NAME)
comprehend = boto3.client("comprehend", region_name=REGION) if USE_COMPREHEND else None

def _now_iso():
    return datetime.now(timezone.utc).isoformat()

def _analyze_text(text):
    if not (USE_COMPREHEND and text and text.strip()):
        return {"sentiment": None, "entities": []}
    result = comprehend.detect_sentiment(Text=text[:4500], LanguageCode="en")
    ents   = comprehend.detect_entities(Text=text[:4500], LanguageCode="en")
    return {
        "sentiment": result.get("Sentiment"),
        "scores": result.get("SentimentScore"),
        "entities": [e["Text"] for e in ents.get("Entities", [])]
    }

def lambda_handler(event, context):
    try:
        body_str = event.get("body") or "{}"
        body = json.loads(body_str)
    except Exception:
        return {"statusCode": 400, "body": json.dumps({"error": "Invalid JSON body"})}

    symbol  = (body.get("symbol") or "UNKNOWN").upper()
    title   = body.get("title")
    content = body.get("content") or ""

    analysis = _analyze_text(content)

    item = {
        "symbol": symbol,
        "created_at": _now_iso(),
        "title": title,
        "content": content[:2000],
        "sentiment": analysis["sentiment"],
        "sentiment_scores": analysis.get("scores"),
        "entities": analysis.get("entities"),
        "request_id": getattr(context, "aws_request_id", None),
        "timestamp": int(time.time())
    }

    table.put_item(Item=item)

    return {
        "statusCode": 201,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "ok": True,
            "symbol": symbol,
            "sentiment": analysis["sentiment"],
            "entities": analysis["entities"]
        })
    }
