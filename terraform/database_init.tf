# Simple Lambda function to initialize database
resource "aws_lambda_function" "simple_db_init" {
  function_name = "simple-db-init"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  filename = "${path.module}/simple_init.zip"
  source_code_hash = data.archive_file.simple_init_zip.output_base64sha256

  environment {
    variables = {
      DB_HOST = aws_db_instance.stock_news_analyzer_db.address
      DB_USER = var.db_username
      DB_PASS = var.db_password
      DB_NAME = "stocknewsanalyzerdb"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# Create the simple init Lambda code
resource "local_file" "simple_init_code" {
  content = <<EOF
import os
import pymysql

def lambda_handler(event, context):
    try:
        conn = pymysql.connect(
            host=os.environ['DB_HOST'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASS'],
            database=os.environ['DB_NAME']
        )
        
        with conn.cursor() as cursor:
            # Drop existing tables
            cursor.execute("DROP TABLE IF EXISTS watchlist")
            cursor.execute("DROP TABLE IF EXISTS prices")
            cursor.execute("DROP TABLE IF EXISTS users")
            cursor.execute("DROP TABLE IF EXISTS stocks")
            
            # Create tables
            cursor.execute("""
                CREATE TABLE users (
                    id VARCHAR(36) PRIMARY KEY NOT NULL, 
                    email VARCHAR(64) NOT NULL,
                    password VARCHAR(64) DEFAULT NULL,
                    watchlist JSON DEFAULT '[]'
                )
            """)
            
            cursor.execute("""
                CREATE TABLE stocks (
                    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
                    ticker VARCHAR(10) NOT NULL UNIQUE
                )
            """)
            
            cursor.execute("""
                CREATE TABLE prices (
                    id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
                    stock_id INT NOT NULL,
                    price DECIMAL(10, 2),
                    change_pct DECIMAL(5, 2),
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    FOREIGN KEY (stock_id) REFERENCES stocks(id),
                    UNIQUE KEY unique_stock_price (stock_id)
                )
            """)
            
            # Insert seed data
            stocks = ['AAPL', 'NFLX', 'AMZN', 'NVDA', 'META', 'MSFT', 'AMD']
            for stock in stocks:
                cursor.execute("INSERT INTO stocks (ticker) VALUES (%s)", (stock,))
            
            conn.commit()
        
        return {'statusCode': 200, 'body': 'Database initialized successfully'}
    except Exception as e:
        print(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': f'Error: {str(e)}'}
    finally:
        if 'conn' in locals():
            conn.close()
EOF
  filename = "${path.module}/simple_init.py"
}

# Create requirements file
resource "local_file" "simple_init_requirements" {
  content  = "pymysql"
  filename = "${path.module}/simple_init_requirements.txt"
}

# Package Lambda with dependencies
resource "null_resource" "package_simple_init" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build/simple_init
      mkdir -p ${path.module}/build/simple_init
      cp ${path.module}/simple_init.py ${path.module}/build/simple_init/index.py
      pip install -r ${path.module}/simple_init_requirements.txt -t ${path.module}/build/simple_init/
    EOT
  }
  depends_on = [local_file.simple_init_code, local_file.simple_init_requirements]
  triggers = {
    always_run = timestamp()
  }
}

# Package the Lambda
data "archive_file" "simple_init_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build/simple_init"
  output_path = "${path.module}/simple_init.zip"
  depends_on  = [null_resource.package_simple_init]
}

# Invoke the simple init Lambda
resource "aws_lambda_invocation" "init_database" {
  function_name = aws_lambda_function.simple_db_init.function_name
  input = jsonencode({})
  depends_on = [
    aws_db_instance.stock_news_analyzer_db,
    aws_lambda_function.simple_db_init
  ]
}