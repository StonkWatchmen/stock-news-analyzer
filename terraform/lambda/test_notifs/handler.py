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

        with conn.cursor() as cur:
            cur.execute("SELECT id,email FROM users;")
            all_user_info = cur.fetchall()

            for user in all_user_info:
                email = user["email"]

                if email.lower() == "demo-user-1@example.com":
                    continue

                # Check if email is verified before attempting to send
                if not is_email_verified(email):
                    print(f"Skipping {email} - not verified")
                    skipped_count += 1
                    ses.verify_email_identity(EmailAddress=email)
                    continue

                message_text = (
                    f"Hello {email},\n\n"
                    "Here is your personalized notification.\n"
                )

                ses.send_email(
                    Source=email,
                    Destination={"ToAddresses": [email]},
                    Message={
                        "Subject": {"Data": f"Your personalized stock updates"},
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