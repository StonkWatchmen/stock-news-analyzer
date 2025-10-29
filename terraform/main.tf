# Provider Configuration
# Specifies the AWS provider and region for Terraform to manage resources in.
provider "aws" {
  region = "us-east-1"
}

# IAM Role for Lambda Function
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json 
}


# Package Lambda Function
data "archive_file" "name" {
  type = "zip"
  source_file = "${path.module}/../lambda/stock_news_analyzer_lambda.py"
  output_path = "${path.module}/../lambda/stock_news_analyzer_lambda.zip"
}


# Lambda Function
resource "aws_lambda_function" "lambda_function" {
  filename         = data.archive_file.name.output_path
  function_name    = "stock_news_analyzer_lambda"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "stock_news_analyzer_lambda.lambda_handler"
  source_code_hash = data.archive_file.name.output_base64sha256
  runtime          = "python3.10"
  
}



# S3 Bucket to store Terraform state
resource "aws_s3_bucket" "terraform_bucket" {
    bucket = "stock-news-analyzer-terraform-state-bucket"
    force_destroy = true

    tags = {
        Name = "Stock News Analyzer Terraform State Bucket"
    }
}

# S3 Bucket to host static website
resource "aws_s3_bucket" "react_bucket" {
    bucket = "stock-news-analyzer-react-app-bucket"
    force_destroy = true

    tags = {
        Name = "Stock News Analyzer React App Bucket"
    }
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
