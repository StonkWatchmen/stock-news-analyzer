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
TIINGO_API_KEY = os.environ.get('TIINGO_API_KEY')
ALPHA_VANTAGE_KEY = os.environ.get('ALPHA_VANTAGE_KEY')  # Keep for news
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

DEFAULT_TICKERS = ["AAPL", "NFLX", "AMZN", "NVDA", "META", "MSFT", "AMD"]

SCHEMA_SQL = [
    """
    CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(255) PRIMARY KEY NOT NULL,
        email VARCHAR(64) NOT NULL UNIQUE
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS stocks (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        ticker VARCHAR(10) NOT NULL UNIQUE
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS watchlist (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        user_id VARCHAR(255) NOT NULL,
        stock_id INT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (stock_id) REFERENCES stocks(id),
        UNIQUE KEY unique_user_stock (user_id, stock_id)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS article_history (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        stock_id INT NOT NULL,
        title VARCHAR(500) NOT NULL,
        keywords TEXT,
        sentiment_score DECIMAL(10, 6),
        recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (stock_id) REFERENCES stocks(id)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS stock_history (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        stock_id INT NOT NULL,
        price DECIMAL(10, 2),
        avg_sentiment DECIMAL(10, 6),
        recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (stock_id) REFERENCES stocks(id)
    )
    """
]


def ensure_schema(conn):
    """Create tables if they do not exist."""
    with conn.cursor() as cursor:
        for statement in SCHEMA_SQL:
            cursor.execute(statement)
    conn.commit()
    print("✓ Database schema ensured")


def ensure_seed_stocks(conn):
    """Insert default tickers if the stocks table is empty."""
    with conn.cursor() as cursor:
        cursor.execute("SELECT COUNT(*) as count FROM stocks")
        count = cursor.fetchone()["count"]
        if count == 0:
            print("Seeding default tickers...")
            cursor.executemany(
                "INSERT INTO stocks (ticker) VALUES (%s)",
                [(ticker,) for ticker in DEFAULT_TICKERS]
            )
            conn.commit()
            print(f"✓ Inserted {len(DEFAULT_TICKERS)} default tickers")
        else:
            print(f"✓ Stocks table already has {count} ticker(s)")


def wait_for_stocks(conn, retries=10, delay=15):
    """Wait until at least one stock exists before backfilling."""
    for attempt in range(retries):
        stocks = get_stocks(conn)
        if stocks:
            return stocks
        print(f"  Attempt {attempt + 1}/{retries}: no stocks yet, waiting {delay}s...")
        time.sleep(delay)

    raise RuntimeError("No stocks found after waiting; aborting backfill.")

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
    """Fetch daily time series data from Tiingo"""
    if not TIINGO_API_KEY:
        print("ERROR: TIINGO_API_KEY not set")
        return None
    
    url = f'https://api.tiingo.com/tiingo/daily/{ticker}/prices'
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Token {TIINGO_API_KEY}'
    }
    
    # Get last 3 months of data
    end_date = datetime.now()
    start_date = end_date - timedelta(days=90)
    
    params = {
        'startDate': start_date.strftime('%Y-%m-%d'),
        'endDate': end_date.strftime('%Y-%m-%d'),
        'format': 'json'
    }
    
    try:
        print(f"  Fetching price data for {ticker} from Tiingo...")
        response = requests.get(url, headers=headers, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        if not data or len(data) == 0:
            print(f"  ⚠ No time series data for {ticker}")
            return None
        
        # Convert Tiingo format to Alpha Vantage-like format for compatibility
        time_series = {}
        for record in data:
            date_str = record['date'][:10]  # Extract date from ISO datetime (YYYY-MM-DD)
            time_series[date_str] = {
                '4. close': record['close']
            }
        
        print(f"  ✓ Retrieved {len(time_series)} days of price data")
        return time_series
        
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 404:
            print(f"  ⚠ Ticker {ticker} not found in Tiingo")
        elif e.response.status_code == 401:
            print(f"  ✗ Tiingo API authentication failed - check API key")
        else:
            print(f"  ✗ Tiingo HTTP error: {e.response.status_code} - {e.response.text}")
        return None
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
    
    # 2. Fetch and process news FIRST
    articles = fetch_news(ticker)
    print(f"  ✓ Found {len(articles)} articles")
    
    # Process articles and build daily sentiment map
    daily_sentiments = {}  # date -> avg sentiment
    
    if articles:
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
        
        if article_texts:
            print(f"  Processing {len(article_texts)} articles with Comprehend...")
            
            # Batch process sentiment and keywords
            sentiments = batch_analyze_sentiment(article_texts)
            keywords_list = batch_extract_keywords(article_texts)
            
            # Store articles and calculate daily averages
            articles_to_store = []
            daily_sentiment_lists = {}  # date -> list of scores
            
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
                if date not in daily_sentiment_lists:
                    daily_sentiment_lists[date] = []
                daily_sentiment_lists[date].append(sentiment)
            
            # Calculate daily averages
            for date, sentiment_list in daily_sentiment_lists.items():
                daily_sentiments[date] = sum(sentiment_list) / len(sentiment_list)
            
            # Bulk insert articles
            with conn.cursor() as cursor:
                cursor.executemany("""
                    INSERT INTO article_history (stock_id, title, keywords, sentiment_score, recorded_at)
                    VALUES (%s, %s, %s, %s, %s)
                """, articles_to_store)
            conn.commit()
            print(f"  ✓ Stored {len(articles_to_store)} articles")
            print(f"  ✓ Calculated sentiment for {len(daily_sentiments)} unique days")
    
    # 3. Now insert prices WITH sentiment where available
    prices_to_store = []
    for date_str, daily_data in time_series.items():
        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
        
        if date_obj < start_date or date_obj > end_date:
            continue
        
        close_price = float(daily_data.get('4. close', 0))
        
        # Get sentiment for this date if available, otherwise 0
        avg_sentiment = daily_sentiments.get(date_obj.date(), 0.0)
        
        prices_to_store.append((stock_id, close_price, avg_sentiment, date_obj))
    
    # Bulk insert prices with sentiment already calculated
    with conn.cursor() as cursor:
        cursor.executemany("""
            INSERT INTO stock_history (stock_id, price, avg_sentiment, recorded_at)
            VALUES (%s, %s, %s, %s)
        """, prices_to_store)
    conn.commit()
    
    # Count how many had real sentiment vs default 0
    sentiment_days = len(daily_sentiments)
    total_days = len(prices_to_store)
    
    print(f"  ✓ Stored {total_days} price records")
    print(f"  ✓ {sentiment_days} days have article sentiment ({sentiment_days/total_days*100:.1f}%)")
    print(f"  ✓ {total_days - sentiment_days} days default to 0 (no articles)")
    
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
    if not all([DB_HOST, DB_USER, DB_PASS, TIINGO_API_KEY]):
        print("\n✗ ERROR: Missing required environment variables")
        print("Required: DB_HOST, DB_USER, DB_PASS, TIINGO_API_KEY")
        print(f"DB_HOST: {'SET' if DB_HOST else 'MISSING'}")
        print(f"DB_USER: {'SET' if DB_USER else 'MISSING'}")
        print(f"DB_PASS: {'SET' if DB_PASS else 'MISSING'}")
        print(f"TIINGO_API_KEY: {'SET' if TIINGO_API_KEY else 'MISSING'}")
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
    
    # Ensure schema + seed data before running backfill
    ensure_schema(conn)
    ensure_seed_stocks(conn)

    try:
        stocks = wait_for_stocks(conn, retries=12, delay=10)
    except RuntimeError as e:
        print(f"\n✗ ERROR: {e}")
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
        
        # Rate limit: Alpha Vantage free tier allows 5 calls per minute
        # Wait 15 seconds between stocks to avoid rate limits
        if i < len(stocks):
            print(f"  Waiting 15 seconds to avoid rate limits...")
            time.sleep(15)
    
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