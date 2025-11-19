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

def wait_for_database(max_retries=20, retry_delay=15):
    """Wait for database to be initialized with schema"""
    print("Waiting for database to be ready...")
    print(f"Will retry up to {max_retries} times with {retry_delay}s delay between attempts")
    
    for attempt in range(max_retries):
        try:
            conn = pymysql.connect(
                host=DB_HOST,
                user=DB_USER,
                password=DB_PASS,
                database=DB_NAME,
                connect_timeout=10,
                cursorclass=pymysql.cursors.DictCursor
            )
            
            # Check if stocks table exists
            with conn.cursor() as cursor:
                cursor.execute("SHOW TABLES LIKE 'stocks'")
                result = cursor.fetchone()
                
                if result:
                    print("✓ Database is ready with schema!")
                    
                    # Also check if there are any stocks
                    cursor.execute("SELECT COUNT(*) as count FROM stocks")
                    stock_count = cursor.fetchone()['count']
                    print(f"✓ Found {stock_count} stocks in database")
                    
                    conn.close()
                    return True
                else:
                    print(f"  Attempt {attempt + 1}/{max_retries}: 'stocks' table not found yet...")
            
            conn.close()
            
        except pymysql.err.OperationalError as e:
            print(f"  Attempt {attempt + 1}/{max_retries}: Cannot connect to database - {e}")
        except pymysql.err.InternalError as e:
            print(f"  Attempt {attempt + 1}/{max_retries}: Database error - {e}")
        except Exception as e:
            print(f"  Attempt {attempt + 1}/{max_retries}: Unexpected error - {e}")
        
        if attempt < max_retries - 1:
            print(f"  Waiting {retry_delay} seconds before retry...")
            time.sleep(retry_delay)
    
    print("✗ Database did not become ready in time")
    return False

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

def fetch_time_series_daily(ticker):
    """Fetch daily time series data from Alpha Vantage"""
    if not ALPHA_VANTAGE_KEY:
        print("ERROR: ALPHA_VANTAGE_KEY not set")
        return None
    
    url = 'https://www.alphavantage.co/query'
    params = {
        'function': 'TIME_SERIES_DAILY',
        'symbol': ticker,
        'apikey': ALPHA_VANTAGE_KEY,
        'outputsize': 'full'  # Last 100 days
    }
    
    try:
        print(f"  Fetching price data for {ticker}...")
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        if 'Time Series (Daily)' not in data:
            print(f"  ⚠ No time series data for {ticker}")
            if 'Note' in data:
                print(f"  API Note: {data['Note']}")
            return None
        
        return data['Time Series (Daily)']
    
    except Exception as e:
        print(f"  ✗ Error fetching time series for {ticker}: {e}")
        return None

def fetch_news(ticker):
    """Fetch news articles for a ticker (last 3 months)"""
    if not ALPHA_VANTAGE_KEY:
        return []
    
    url = 'https://www.alphavantage.co/query'
    
    # Calculate 3 months ago
    start_date = datetime.now() - timedelta(days=365)
    
    params = {
        'function': 'NEWS_SENTIMENT',
        'tickers': ticker,
        'apikey': ALPHA_VANTAGE_KEY,
        'time_from': start_date.strftime('%Y%m%dT0000'),
        'limit': 200,
        'sort': 'LATEST'
    }
    
    try:
        print(f"  Fetching news for {ticker}...")
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        return data.get('feed', [])
    
    except Exception as e:
        print(f"  ✗ Error fetching news for {ticker}: {e}")
        return []

def batch_analyze_sentiment(texts):
    """Batch analyze sentiment for multiple texts"""
    if not comprehend or not texts:
        return [0.0] * len(texts)
    
    results = []
    
    # Process in batches of 25 (Comprehend limit)
    batch_size = 25
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        
        # Truncate texts to 5000 bytes
        truncated_batch = []
        for text in batch:
            if len(text.encode('utf-8')) > 5000:
                text = text[:1200]
            truncated_batch.append(text)
        
        try:
            response = comprehend.batch_detect_sentiment(
                TextList=truncated_batch,
                LanguageCode='en'
            )
            
            for result in response['ResultList']:
                scores = result['SentimentScore']
                sentiment_score = scores['Positive'] - scores['Negative']
                results.append(sentiment_score)
        
        except Exception as e:
            print(f"    ⚠ Batch sentiment error: {e}")
            results.extend([0.0] * len(batch))
    
    return results

def batch_extract_keywords(texts):
    """Batch extract keywords for multiple texts"""
    if not comprehend or not texts:
        return [""] * len(texts)
    
    results = []
    
    # Process in batches of 25
    batch_size = 25
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        
        # Truncate texts
        truncated_batch = []
        for text in batch:
            if len(text.encode('utf-8')) > 5000:
                text = text[:1200]
            truncated_batch.append(text)
        
        try:
            response = comprehend.batch_detect_key_phrases(
                TextList=truncated_batch,
                LanguageCode='en'
            )
            
            for result in response['ResultList']:
                keywords = [phrase['Text'] for phrase in result.get('KeyPhrases', [])[:10]]
                results.append(', '.join(keywords))
        
        except Exception as e:
            print(f"    ⚠ Batch keywords error: {e}")
            results.extend([""] * len(batch))
    
    return results

def backfill_stock(conn, stock_id, ticker, months=12):
    """Backfill historical data for a stock"""
    print(f"\n{'='*60}")
    print(f"Processing {ticker}")
    print(f"{'='*60}")
    
    # Calculate date range
    end_date = datetime.now()
    start_date = end_date - timedelta(days=months*30)
    
    # 1. Fetch historical prices
    time_series = fetch_time_series_daily(ticker)
    
    if not time_series:
        print(f"  ✗ Skipping {ticker} - no price data")
        return False
    
    # Store prices
    prices_to_store = []
    for date_str, daily_data in time_series.items():
        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
        
        if date_obj < start_date or date_obj > end_date:
            continue
        
        close_price = float(daily_data.get('4. close', 0))
        prices_to_store.append((stock_id, close_price, date_obj))
    
    # Bulk insert prices
    with conn.cursor() as cursor:
        cursor.executemany("""
            INSERT INTO stock_history (stock_id, price, avg_sentiment, recorded_at)
            VALUES (%s, %s, NULL, %s)
        """, prices_to_store)
    conn.commit()
    print(f"  ✓ Stored {len(prices_to_store)} price records")
    
    # Rate limit between API calls
    time.sleep(1)
    
    # 2. Fetch and process news
    articles = fetch_news(ticker)
    print(f"  ✓ Found {len(articles)} articles")
    
    if not articles:
        print(f"  ⚠ No articles to process")
        return True
    
    # Prepare article data for batch processing
    article_texts = []
    article_data = []
    
    for article in articles:
        title = article.get('title', '')
        summary = article.get('summary', '')
        time_published = article.get('time_published', '')
        
        if not title or not time_published:
            continue
        
        try:
            published_dt = datetime.strptime(time_published, '%Y%m%dT%H%M%S')
        except ValueError:
            continue
        
        text = f"{title}. {summary}"
        article_texts.append(text)
        article_data.append({
            'title': title[:500],
            'published_dt': published_dt,
            'published_date': published_dt.date()
        })
    
    if not article_texts:
        print(f"  ⚠ No valid articles to process")
        return True
    
    print(f"  Processing {len(article_texts)} articles with Comprehend...")
    
    # Batch process sentiment and keywords
    sentiments = batch_analyze_sentiment(article_texts)
    keywords_list = batch_extract_keywords(article_texts)
    
    # Store articles and track daily sentiments
    daily_sentiments = {}  # date -> list of sentiment scores
    articles_to_store = []
    
    for i, data in enumerate(article_data):
        sentiment = sentiments[i]
        keywords = keywords_list[i]
        
        articles_to_store.append((
            stock_id,
            data['title'],
            keywords,
            sentiment,
            data['published_dt']
        ))
        
        # Track for daily average
        date = data['published_date']
        if date not in daily_sentiments:
            daily_sentiments[date] = []
        daily_sentiments[date].append(sentiment)
    
    # Bulk insert articles
    with conn.cursor() as cursor:
        cursor.executemany("""
            INSERT INTO article_history (stock_id, title, keywords, sentiment_score, recorded_at)
            VALUES (%s, %s, %s, %s, %s)
        """, articles_to_store)
    conn.commit()
    print(f"  ✓ Stored {len(articles_to_store)} articles")
    
    # Update stock_history with average daily sentiment
    sentiment_updates = []
    for date, sentiments in daily_sentiments.items():
        avg_sentiment = sum(sentiments) / len(sentiments)
        sentiment_updates.append((avg_sentiment, stock_id, date))
    
    with conn.cursor() as cursor:
        cursor.executemany("""
            UPDATE stock_history
            SET avg_sentiment = %s
            WHERE stock_id = %s 
            AND DATE(recorded_at) = %s
        """, sentiment_updates)
    conn.commit()
    print(f"  ✓ Updated sentiment for {len(sentiment_updates)} days")
    
    print(f"  ✓ Completed {ticker}")
    return True

def main():
    """Main backfill process"""
    start_time = time.time()
    
    print("="*60)
    print("Stock News Analyzer - Historical Data Backfill")
    print("="*60)
    print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Validate environment variables
    if not all([DB_HOST, DB_USER, DB_PASS, ALPHA_VANTAGE_KEY]):
        print("\n✗ ERROR: Missing required environment variables")
        print("Required: DB_HOST, DB_USER, DB_PASS, ALPHA_VANTAGE_KEY")
        print(f"DB_HOST: {'SET' if DB_HOST else 'MISSING'}")
        print(f"DB_USER: {'SET' if DB_USER else 'MISSING'}")
        print(f"DB_PASS: {'SET' if DB_PASS else 'MISSING'}")
        print(f"ALPHA_VANTAGE_KEY: {'SET' if ALPHA_VANTAGE_KEY else 'MISSING'}")
        sys.exit(1)
    
    print(f"\n✓ Environment variables validated")
    print(f"  DB_HOST: {DB_HOST}")
    print(f"  DB_NAME: {DB_NAME}")
    print(f"  AWS_REGION: {AWS_REGION}")
    
    # Wait for database to be initialized with schema
    print("\n" + "="*60)
    if not wait_for_database(max_retries=20, retry_delay=15):
        print("✗ ERROR: Database schema not initialized in time")
        print("The init_db_lambda may not have completed successfully")
        sys.exit(1)
    
    # Connect to database
    print("\n" + "="*60)
    try:
        conn = get_db_connection()
        print(f"✓ Connected to database at {DB_HOST}")
    except Exception as e:
        print(f"✗ ERROR: Could not connect to database: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    
    # Get stocks to backfill
    try:
        stocks = get_stocks(conn)
    except Exception as e:
        print(f"✗ ERROR: Could not fetch stocks: {e}")
        import traceback
        traceback.print_exc()
        conn.close()
        sys.exit(1)
    
    if not stocks:
        print("\n⚠ WARNING: No stocks found in database")
        print("Please add stocks to the 'stocks' table before running backfill")
        conn.close()
        sys.exit(0)
    
    print(f"\n✓ Found {len(stocks)} stocks to backfill")
    print(f"  Stocks: {', '.join([s['ticker'] for s in stocks])}")
    
    # Backfill each stock
    print("\n" + "="*60)
    print("STARTING BACKFILL PROCESS")
    print("="*60)
    
    success_count = 0
    for i, stock in enumerate(stocks, 1):
        print(f"\n[{i}/{len(stocks)}] Starting {stock['ticker']}...")
        
        try:
            if backfill_stock(conn, stock['id'], stock['ticker'], months=3):
                success_count += 1
        except Exception as e:
            print(f"  ✗ ERROR processing {stock['ticker']}: {e}")
            import traceback
            traceback.print_exc()
            continue
        
        # Small delay between stocks (API rate limit)
        if i < len(stocks):
            time.sleep(1)
    
    conn.close()
    
    elapsed = time.time() - start_time
    
    print("\n" + "="*60)
    print("BACKFILL COMPLETE")
    print("="*60)
    print(f"✓ Successfully backfilled {success_count}/{len(stocks)} stocks")
    print(f"⏱  Time elapsed: {elapsed:.1f} seconds ({elapsed/60:.1f} minutes)")
    print(f"📅 End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    if success_count < len(stocks):
        print(f"\n⚠ WARNING: {len(stocks) - success_count} stock(s) failed to backfill")
        sys.exit(1)

if __name__ == "__main__":
    main()