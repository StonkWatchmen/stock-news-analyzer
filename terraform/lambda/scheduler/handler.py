import os
import json
import pymysql
import urllib.request, urllib.parse
from datetime import datetime
from decimal import Decimal
import boto3
import time

# AWS Clients
comprehend = boto3.client('comprehend', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Environment variables
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASS = os.environ['DB_PASS']
DB_NAME = os.environ['DB_NAME']
ALPHA_VANTAGE_KEY = os.environ.get('ALPHA_VANTAGE_KEY')

def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor
    )

def _http_get_json(url):
    with urllib.request.urlopen(url, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))

def get_all_stocks(conn):
    with conn.cursor() as cursor:
        cursor.execute("SELECT id, ticker FROM stocks ORDER BY ticker")
        return cursor.fetchall()

def fetch_stock_price(ticker):
    """Fetch current stock price from Alpha Vantage"""
    if not ALPHA_VANTAGE_KEY:
        return None
    
    base_url = "https://www.alphavantage.co/query"
    params = {
        "function": "GLOBAL_QUOTE",
        "symbol": ticker,
        "apikey": ALPHA_VANTAGE_KEY
    }
    
    try:
        data = _http_get_json(f"{base_url}?{urllib.parse.urlencode(params)}")
        quote = data.get("Global Quote", {})
        
        if quote:
            price = float(Decimal(quote.get("05. price", "0")))
            return price
        return None
    
    except Exception as e:
        print(f"Error fetching price for {ticker}: {str(e)}")
        return None

def fetch_news_articles(ticker):
    """Fetch news articles from Alpha Vantage"""
    if not ALPHA_VANTAGE_KEY:
        return []
    
    base_url = "https://www.alphavantage.co/query"
    params = {
        "function": "NEWS_SENTIMENT",
        "tickers": ticker,
        "apikey": ALPHA_VANTAGE_KEY,
        "limit": 20
    }
    
    try:
        data = _http_get_json(f"{base_url}?{urllib.parse.urlencode(params)}")
        return data.get("feed", [])
    
    except Exception as e:
        print(f"Error fetching news for {ticker}: {str(e)}")
        return []

def extract_keywords(text):
    """Extract keywords using Comprehend"""
    try:
        if len(text.encode('utf-8')) > 5000:
            text = text[:1200]
        
        response = comprehend.detect_key_phrases(
            Text=text,
            LanguageCode='en'
        )
        
        keywords = [phrase['Text'] for phrase in response.get('KeyPhrases', [])[:10]]
        return ', '.join(keywords)
    
    except Exception as e:
        print(f"Error extracting keywords: {str(e)}")
        return ""

def analyze_sentiment(text):
    """Analyze sentiment using Comprehend"""
    try:
        if len(text.encode('utf-8')) > 5000:
            text = text[:1200]
        
        response = comprehend.detect_sentiment(
            Text=text,
            LanguageCode='en'
        )
        
        scores = response['SentimentScore']
        # Calculate score: positive - negative (range: -1 to 1)
        sentiment_score = scores['Positive'] - scores['Negative']
        
        return sentiment_score
    
    except Exception as e:
        print(f"Error analyzing sentiment: {str(e)}")
        return None

def store_article(conn, stock_id, title, keywords, sentiment_score):
    """Store article in article_history"""
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO article_history (stock_id, title, keywords, sentiment_score)
                VALUES (%s, %s, %s, %s)
            """, (stock_id, title, keywords, sentiment_score))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error storing article: {str(e)}")
        conn.rollback()
        return False

def store_stock_history(conn, stock_id, price, avg_sentiment):
    """Store stock history snapshot"""
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO stock_history (stock_id, price, avg_sentiment)
                VALUES (%s, %s, %s)
            """, (stock_id, price, avg_sentiment))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error storing stock history: {str(e)}")
        conn.rollback()
        return False

def process_stock(conn, stock_id, ticker):
    """Process a single stock"""
    print(f"\n{'='*60}")
    print(f"Processing {ticker}")
    print(f"{'='*60}")
    
    # 1. Fetch current price
    price = fetch_stock_price(ticker)
    if price:
        print(f"Price: ${price}")
    
    time.sleep(1)
    
    # 2. Fetch news articles
    articles = fetch_news_articles(ticker)
    print(f"Found {len(articles)} articles")
    
    sentiment_scores = []
    articles_stored = 0
    
    # 3. Process each article
    for article in articles[:10]:  # Process up to 10 articles
        title = article.get('title', '')
        summary = article.get('summary', '')
        
        if not title:
            continue
        
        text = f"{title}. {summary}"
        
        # Extract keywords
        keywords = extract_keywords(text)
        
        # Get sentiment
        sentiment_score = analyze_sentiment(text)
        
        if sentiment_score is not None:
            sentiment_scores.append(sentiment_score)
            
            # Store article
            if store_article(conn, stock_id, title[:500], keywords, sentiment_score):
                articles_stored += 1
                print(f"Stored: {title[:50]}... (sentiment: {sentiment_score:.3f})")
        
        time.sleep(0.5)
    
    # 4. Calculate average sentiment
    avg_sentiment = None
    if sentiment_scores:
        avg_sentiment = sum(sentiment_scores) / len(sentiment_scores)
        print(f"Average sentiment: {avg_sentiment:.3f}")
    
    # 5. Store stock history
    store_stock_history(conn, stock_id, price, avg_sentiment)
    
    return {
        'ticker': ticker,
        'price': price,
        'articles_stored': articles_stored,
        'avg_sentiment': avg_sentiment
    }

def lambda_handler(event, context):
    """
    Hourly Lambda: Collect prices and news, analyze sentiment
    """
    print(f"Started at {datetime.now().isoformat()}")
    
    try:
        conn = get_db_connection()
        stocks = get_all_stocks(conn)
        
        if not stocks:
            return {
                "statusCode": 200,
                "body": json.dumps({"message": "No stocks to process"})
            }
        
        print(f"Processing {len(stocks)} stocks")
        
        results = []
        
        for stock in stocks:
            try:
                result = process_stock(conn, stock['id'], stock['ticker'])
                results.append(result)
                time.sleep(2)  # Rate limit
            except Exception as e:
                print(f"Error processing {stock['ticker']}: {str(e)}")
                continue
        
        conn.close()
        
        summary = {
            "message": "Collection complete",
            "stocks_processed": len(results),
            "results": results,
            "timestamp": datetime.now().isoformat()
        }
        
        print(json.dumps(summary, indent=2))
        
        return {
            "statusCode": 200,
            "body": json.dumps(summary)
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }