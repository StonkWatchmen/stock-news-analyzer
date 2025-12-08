import os
import pymysql
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

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

def lambda_handler(event, context):
    """
    Post-confirmation Lambda trigger to add user to database.
    Handles duplicate users gracefully.
    """
    try:
        user_id = event['request']['userAttributes']['sub']
        email = event['request']['userAttributes'].get('email')
        
        if not user_id or not email:
            logger.error(f"Missing required attributes: user_id={user_id}, email={email}")
            # Return event to allow Cognito confirmation to succeed
            return event
        
        conn = None
        try:
            conn = get_connection()
            
            with conn.cursor() as cur:
                # Use INSERT IGNORE to handle duplicates gracefully
                # If user already exists, this will silently succeed
                cur.execute(
                    "INSERT IGNORE INTO users (id, email) VALUES (%s, %s)",
                    (user_id, email)
                )
                conn.commit()
                
                # Check if row was actually inserted
                if cur.rowcount > 0:
                    logger.info(f"Successfully added user {email} ({user_id}) to database")
                else:
                    logger.info(f"User {email} ({user_id}) already exists in database")
            
            return event
            
        except pymysql.err.IntegrityError as e:
            # Handle duplicate key errors gracefully
            logger.warning(f"User {email} ({user_id}) already exists: {e}")
            # Return event to allow Cognito confirmation to succeed
            return event
            
        except Exception as e:
            logger.error(f"Database error adding user {email} ({user_id}): {e}", exc_info=True)
            # Return event anyway - don't fail Cognito confirmation due to DB issues
            # The user can be added manually later if needed
            return event
            
        finally:
            if conn:
                conn.close()
                
    except Exception as e:
        logger.error(f"Unexpected error in add_user Lambda: {e}", exc_info=True)
        # Always return event to allow Cognito confirmation to succeed
        return event
