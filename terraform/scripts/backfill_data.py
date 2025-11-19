import os
import sys
import time
import requests
import pymysql
from datetime import datetime, timedelta
from decimal import Decimal

# Configuration from environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_USER = os.environ.get('DB_USER')
DB_PASS = os.environ.get('DB_PASS')
DB_NAME = os.environ.get('DB_NAME', 'stocknewsanalyzerdb')
ALPHA_VANTAGE_KEY = os.environ.get('ALPHA_VANTAGE_KEY')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

# Boto3 for Comprehend
try:
    import boto3
    comprehend = boto3.client('comprehend', region_name=AWS_REGION)
except Exception as e:
    print(f"Warning: Could not initialize Comprehend client: {e}")
    comprehend = None

def get_db_connection():
    """Connect to RDS database"""
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        connect_timeout=10,
        cursorclass=pymysql.cursors.DictCursor
    )

def get_stocks(conn):
    """Get all stock tickers from database"""
    with conn.cursor() as cursor:
        cursor.execute("SELECT id, ticker FROM stocks ORDER BY ticker")
        return cursor.fetchall()

def fetch_time_series_daily(ticker, outputsize='full'):
    """Fetch daily time series data from Alpha Vantage"""
    if not ALPHA_VANTAGE_KEY:
        print("ERROR: ALPHA_VANTAGE_KEY not set")
        return None
    
    url = 'https://www.alphavantage.co/query'
    params = {
        'function': 'TIME_SERIES_DAILY',
        'symbol': ticker,
        'apikey': ALPHA_VANTAGE_KEY,
        'outputsize': outputsize  # 'compact' = last 100 days, 'full' = 20+ years
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        if 'Time Series (Daily)' not in data:
            print(f"No time series data for {ticker}")
            return None
        
        return data['Time Series (Daily)']
    
    except Exception as e:
        print(f"Error fetching time series for {ticker}: {e}")
        return None

def fetch_news_for_date_range(ticker, start_date, end_date):
    """Fetch news articles for a ticker in a date range"""
    if not ALPHA_VANTAGE_KEY:
        return []
    
    url = 'https://www.alphavantage.co/query'
    params = {
        'function': 'NEWS_SENTIMENT',
        'tickers': ticker,
        'apikey': ALPHA_VANTAGE_KEY,
        'time_from': start_date.strftime('%Y%m%dT0000'),
        'time_to': end_date.strftime('%Y%m%dT2359'),
        'limit': 200,
        'sort': 'LATEST'
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        return data.get('feed', [])
    
    except Exception as e:
        print(f"Error fetching news for {ticker} ({start_date} to {end_date}): {e}")
        return []

def extract_keywords(text):
    """Extract keywords using Comprehend"""
    if not comprehend:
        return ""
    
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
        print(f"Error extracting keywords: {e}")
        return ""

def analyze_sentiment(text):
    """Analyze sentiment using Comprehend"""
    if not comprehend:
        return None
    
    try:
        if len(text.encode('utf-8')) > 5000:
            text = text[:1200]
        
        response = comprehend.detect_sentiment(
            Text=text,
            LanguageCode='en'
        )
        
        scores = response['SentimentScore']
        sentiment_score = scores['Positive'] - scores['Negative']
        
        return sentiment_score
    
    except Exception as e:
        print(f"Error analyzing sentiment: {e}")
        return None

def store_article(conn, stock_id, title, keywords, sentiment_score, recorded_at):
    """Store article in article_history"""
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO article_history (stock_id, title, keywords, sentiment_score, recorded_at)
                VALUES (%s, %s, %s, %s, %s)
            """, (stock_id, title[:500], keywords, sentiment_score, recorded_at))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error storing article: {e}")
        conn.rollback()
        return False

def store_stock_history(conn, stock_id, price, avg_sentiment, recorded_at):
    """Store stock history record"""
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO stock_history (stock_id, price, avg_sentiment, recorded_at)
                VALUES (%s, %s, %s, %s)
            """, (stock_id, price, avg_sentiment, recorded_at))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error storing stock history: {e}")
        conn.rollback()
        return False

def backfill_stock(conn, stock_id, ticker, months=3):
    """Backfill historical data for a stock"""
    print(f"\n{'='*60}")
    print(f"Backfilling {ticker} - Last {months} months")
    print(f"{'='*60}")
    
    # Calculate date range
    end_date = datetime.now()
    start_date = end_date - timedelta(days=months*30)
    
    # 1. Fetch historical prices
    print(f"\nFetching price history for {ticker}...")
    time_series = fetch_time_series_daily(ticker, outputsize='compact')
    
    if not time_series:
        print(f"No price data available for {ticker}")
        return False
    
    # Filter to last 3 months
    prices_stored = 0
    for date_str, daily_data in time_series.items():
        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
        
        if date_obj < start_date or date_obj > end_date:
            continue
        
        close_price = float(daily_data.get('4. close', 0))
        
        # For now, store with null sentiment (will be filled by news)
        if store_stock_history(conn, stock_id, close_price, None, date_obj):
            prices_stored += 1
    
    print(f"Stored {prices_stored} price records")
    
    # Rate limit - Alpha Vantage free tier: 5 calls/min, 500 calls/day
    print("Waiting 15 seconds (API rate limit)...")
    time.sleep(15)
    
    # 2. Fetch news and calculate daily sentiment
    print(f"\nFetching news for {ticker}...")
    
    # Fetch news in weekly chunks to avoid overwhelming the API
    current_date = start_date
    total_articles = 0
    
    while current_date < end_date:
        chunk_end = min(current_date + timedelta(days=7), end_date)
        
        articles = fetch_news_for_date_range(ticker, current_date, chunk_end)
        print(f"Found {len(articles)} articles from {current_date.date()} to {chunk_end.date()}")
        
        # Process articles
        daily_sentiments = {}  # date -> list of sentiment scores
        
        for article in articles:
            title = article.get('title', '')
            summary = article.get('summary', '')
            time_published = article.get('time_published', '')
            
            if not title or not time_published:
                continue
            
            try:
                published_dt = datetime.strptime(time_published, '%Y%m%dT%H%M%S')
                published_date = published_dt.date()
            except ValueError:
                continue
            
            text = f"{title}. {summary}"
            
            # Extract keywords and sentiment
            keywords = extract_keywords(text) if comprehend else ""
            sentiment_score = analyze_sentiment(text) if comprehend else 0.0
            
            if sentiment_score is not None:
                # Store article
                store_article(conn, stock_id, title, keywords, sentiment_score, published_dt)
                
                # Track for daily average
                if published_date not in daily_sentiments:
                    daily_sentiments[published_date] = []
                daily_sentiments[published_date].append(sentiment_score)
                
                total_articles += 1
            
            # Small delay between Comprehend calls
            time.sleep(0.3)
        
        # Update stock_history with average daily sentiment
        for date, sentiments in daily_sentiments.items():
            avg_sentiment = sum(sentiments) / len(sentiments)
            
            with conn.cursor() as cursor:
                cursor.execute("""
                    UPDATE stock_history
                    SET avg_sentiment = %s
                    WHERE stock_id = %s 
                    AND DATE(recorded_at) = %s
                    AND avg_sentiment IS NULL
                """, (avg_sentiment, stock_id, date))
            conn.commit()
        
        current_date = chunk_end
        
        # Rate limit between chunks
        print("Waiting 15 seconds (API rate limit)...")
        time.sleep(15)
    
    print(f"\nCompleted backfill for {ticker}:")
    print(f"  - {prices_stored} price records")
    print(f"  - {total_articles} articles processed")
    
    return True

def main():
    """Main backfill process"""
    print("="*60)
    print("Stock News Analyzer - Historical Data Backfill")
    print("="*60)
    
    # Validate environment variables
    if not all([DB_HOST, DB_USER, DB_PASS, ALPHA_VANTAGE_KEY]):
        print("ERROR: Missing required environment variables")
        print("Required: DB_HOST, DB_USER, DB_PASS, ALPHA_VANTAGE_KEY")
        sys.exit(1)
    
    # Connect to database
    try:
        conn = get_db_connection()
        print(f"✓ Connected to database at {DB_HOST}")
    except Exception as e:
        print(f"ERROR: Could not connect to database: {e}")
        sys.exit(1)
    
    # Get stocks to backfill
    stocks = get_stocks(conn)
    
    if not stocks:
        print("No stocks found in database. Please add stocks first.")
        sys.exit(1)
    
    print(f"\nFound {len(stocks)} stocks to backfill")
    print(f"Stocks: {', '.join([s['ticker'] for s in stocks])}")
    
    # Backfill each stock
    success_count = 0
    for i, stock in enumerate(stocks, 1):
        print(f"\n[{i}/{len(stocks)}] Processing {stock['ticker']}...")
        
        try:
            if backfill_stock(conn, stock['id'], stock['ticker'], months=3):
                success_count += 1
        except Exception as e:
            print(f"ERROR processing {stock['ticker']}: {e}")
            continue
    
    conn.close()
    
    print("\n" + "="*60)
    print("BACKFILL COMPLETE")
    print(f"Successfully backfilled {success_count}/{len(stocks)} stocks")
    print("="*60)

if __name__ == "__main__":
    main()