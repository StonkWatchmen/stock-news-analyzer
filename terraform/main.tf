# Provider Configuration
# Specifies the AWS provider and region for Terraform to manage resources in.
provider "aws" {
  region = "us-east-1"
}

# S3 Bucket to store Terraform state
resource "aws_s3_bucket" "terraform_bucket" {
    bucket = "stonkwatchmen-stock-news-analyzer-terraform-state-bucket"
    force_destroy = true

    tags = {
        Name = "Stock News Analyzer Terraform State Bucket"
    }
}

# S3 Bucket to host static website
resource "aws_s3_bucket" "react_bucket" {
    bucket = "stonkwatchmen-stock-news-analyzer-react-app-bucket"
    force_destroy = true

    tags = {
        Name = "Stock News Analyzer React App Bucket"
    }
}

resource "aws_s3_bucket_website_configuration" "react_bucket_website_config" {
  bucket = aws_s3_bucket.react_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  depends_on = [ aws_s3_bucket.react_bucket ]
}

resource "aws_s3_bucket_public_access_block" "react_bucket_public_access_block" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "react_bucket_policy" {
  bucket = aws_s3_bucket.react_bucket.id

  policy = data.aws_iam_policy_document.get_object_iam_policy.json
  depends_on = [aws_s3_bucket_public_access_block.react_bucket_public_access_block]
}

# RDS Instance
resource "aws_db_instance" "stock_news_analyzer_db" {
  identifier             = "stock-news-analyzer-db"                           # Unique identifier for the RDS instance
  allocated_storage      = 20                                                 # 20GB of storage
  storage_type           = "gp2"                                              # General Purpose SSD
  engine                 = "mysql"                                            # MySQL database engine
  engine_version         = "8.0"                                              # MySQL version 8.0
  instance_class         = "db.t3.micro"                                      # Free tier eligible instance type
  db_name                = "stocknewsanalyzerdb"                              # Name of the Stock News Analyzer database
  username               = var.db_username                                    # Database admin username
  password               = var.db_password                                    # Replace with a secure password
  parameter_group_name   = "default.mysql8.0"                                 # Default parameter group for MySQL 8.0
  skip_final_snapshot    = true                                               # Skip final snapshot when destroying the database
  vpc_security_group_ids = [aws_security_group.rds_sg.id]                     # Attach the RDS security group
  db_subnet_group_name   = aws_db_subnet_group.stock_news_analyzer_db_subnet_group.name # Use the created subnet group
}

resource "aws_instance" "db_init" {
  ami           = data.aws_ami.amazonlinux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum install -y mysql
    
    mysql -h ${aws_db_instance.stock_news_analyzer_db.address} \
          -u admin \
          -p${var.db_password} \
          stocknewsanalyzerdb << 'MYSQL'
    
    DROP TABLE IF EXISTS watchlist;
    DROP TABLE IF EXISTS users;
    DROP TABLE IF EXISTS stocks;

    CREATE TABLE users (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL, 
        username VARCHAR(16) NOT NULL,
        password VARCHAR(128) NOT NULL,
        phone_number VARCHAR(10)
    );

    CREATE TABLE stocks (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        ticker VARCHAR(5) NOT NULL
    );

    CREATE TABLE watchlist (
        id INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
        user_id INTEGER NOT NULL,
        stock_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (stock_id) REFERENCES stocks(id)
    );

    INSERT INTO stocks(ticker) 
    VALUES
        ('AAPL'),
        ('NFLX'),
        ('AMZN'),
        ('NVDA'),
        ('META'),
        ('MSFT'),
        ('AMD');
    MYSQL

    echo ""
      echo "Verifying tables..."
      echo "-----------------------------------"
      mysql -h ${aws_db_instance.stock_news_analyzer_db.address} \
            -u admin \
            -p${var.db_password} \
            stocknewsanalyzerdb -e "SHOW TABLES;"
      
      echo ""
      echo "Checking stocks data..."
      echo "-----------------------------------"
      mysql -h ${aws_db_instance.stock_news_analyzer_db.address} \
            -u admin \
            -p${var.db_password} \
            stocknewsanalyzerdb -e "SELECT * FROM stocks;"
  EOF
  
  depends_on = [ aws_db_instance.stock_news_analyzer_db ]

  tags = {
    Name = "db-init"
  }
}