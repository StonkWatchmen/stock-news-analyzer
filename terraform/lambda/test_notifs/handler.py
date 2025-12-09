import json
import boto3
import os
import pymysql

ses = boto3.client("ses")

def get_connection():
    """Establish a connection to the RDS MySQL instance."""
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ["DB_NAME"],
        port=int(os.environ.get("DB_PORT", 3306)),
        connect_timeout=5,
        autocommit=False,
        cursorclass=pymysql.cursors.DictCursor
    )

def is_email_verified(email):
    """Check if an email is verified in SES."""
    try:
        response = ses.get_identity_verification_attributes(
            Identities=[email]
        )
        
        verification_attrs = response.get('VerificationAttributes', {})
        
        if email in verification_attrs:
            status = verification_attrs[email]['VerificationStatus']
            return status == 'Success'
        
        return False
    except Exception as e:
        print(f"Error checking verification for {email}: {str(e)}")
        return False

def get_user_watchlist_data(cur, user_id):
    """Get stocks from user's watchlist with latest price and sentiment."""
    query = """
        SELECT 
            s.ticker,
            sh.price,
            sh.avg_sentiment,
            sh.recorded_at as last_updated
        FROM watchlist w
        JOIN stocks s ON w.stock_id = s.id
        LEFT JOIN (
            SELECT stock_id, price, avg_sentiment, recorded_at
            FROM stock_history sh1
            WHERE recorded_at = (
                SELECT MAX(recorded_at)
                FROM stock_history sh2
                WHERE sh2.stock_id = sh1.stock_id
            )
        ) sh ON s.id = sh.stock_id
        WHERE w.user_id = %s
        ORDER BY s.ticker
    """
    
    cur.execute(query, (user_id,))
    return cur.fetchall()

def format_watchlist_email(email, watchlist_data):
    """Format watchlist data into email text."""
    if not watchlist_data:
        return (
            f"Hello,\n\n"
            "You don't have any stocks in your watchlist yet.\n"
            "Add some stocks to start receiving personalized updates!\n\n"
            "Best regards,\n"
            "Stock News Analyzer"
        )
    
    message = f"Hello,\n\n"
    message += "Here are your watchlist stocks and their latest updates:\n\n"
    
    for stock in watchlist_data:
        ticker = stock['ticker']
        price = stock['price']
        sentiment = stock['avg_sentiment']
        
        message += f"📊 {ticker}\n"
        
        if price is not None:
            message += f"   Price: ${price:.2f}\n"
        else:
            message += f"   Price: N/A\n"
        
        if sentiment is not None:
            sentiment_label = "Positive" if sentiment > 0 else "Negative" if sentiment < 0 else "Neutral"
            message += f"   Sentiment: {sentiment_label} ({sentiment:.3f})\n"
        else:
            message += f"   Sentiment: N/A\n"
        
        message += "\n"
    
    message += "Stay informed and happy investing!\n\n"
    message += "Best regards,\n"
    message += "Stock News Analyzer"
    
    return message

def lambda_handler(event, context):
    # CORS headers for all responses
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "POST,OPTIONS"
    }
    
    try:
        conn = get_connection()
        
        sent_count = 0
        skipped_count = 0
        skipped_emails = []

        with conn.cursor() as cur:
            cur.execute("SELECT id, email FROM users;")
            all_user_info = cur.fetchall()

            for user in all_user_info:
                user_id = user["id"]
                email = user["email"]

                if email.lower() == "demo-user-1@example.com":
                    continue

                # Check if email is verified before attempting to send
                if not is_email_verified(email):
                    print(f"Skipping {email} - not verified")
                    skipped_count += 1
                    skipped_emails.append(email)
                    ses.verify_email_identity(EmailAddress=email)
                    continue

                # Get user's watchlist data
                watchlist_data = get_user_watchlist_data(cur, user_id)
                
                # Format the email message
                message_text = format_watchlist_email(email, watchlist_data)

                ses.send_email(
                    Source=email,
                    Destination={"ToAddresses": [email]},
                    Message={
                        "Subject": {"Data": "Your Stock Watchlist Update"},
                        "Body": {"Text": {"Data": message_text}}
                    }
                )
                sent_count += 1

        return {
            "isBase64Encoded": False,
            "statusCode": 200,
            "headers": cors_headers,
            "body": json.dumps({
                "status": "success",
                "sent": sent_count,
                "skipped": skipped_count,
                "skipped_emails": skipped_emails
            })
        }
    except Exception as e:
        # Return error response with CORS headers
        return {
            "isBase64Encoded": False,
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"status": "error", "message": str(e)})
        }