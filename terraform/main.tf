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
