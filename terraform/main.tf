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
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

#IAM Policy Attachments for Lambda Logs & Comprehend
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "comprehend_access" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/ComprehendFullAccess"
}

data "archive_file" "name" {
  type        = "zip"
  source_file = "${path.module}/lambda_function/lambda_handler.py"
  output_path = "${path.module}/lambda.zip"
}


# Lambda Function & Public URL

resource "aws_lambda_function" "lambda_function" {
  filename         = data.archive_file.name.output_path
  function_name    = "stock_news_analyzer_lambda"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "lambda_handler.lambda_handler"
  source_code_hash = data.archive_file.name.output_base64sha256
  runtime          = "python3.12"
  timeout          = 15
  architectures    = ["x86_64"]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.comprehend_access
  ]
}

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.lambda_function.function_name
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["*"]
  }
}


# S3 Buckets
###############################################
# S3 Bucket to store Terraform state

resource "aws_s3_bucket" "terraform_bucket" {
  bucket        = "stock-news-analyzer-terraform-state-bucket"
  force_destroy = true

  tags = {
    Name = "Stock News Analyzer Terraform State Bucket"
  }
}

# S3 Bucket to host static website
resource "aws_s3_bucket" "react_bucket" {
  bucket        = "stock-news-analyzer-react-app-bucket"
  force_destroy = true

  tags = {
    Name = "Stock News Analyzer React App Bucket"
  }
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "react_bucket_website_config" {
  bucket = aws_s3_bucket.react_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  depends_on = [aws_s3_bucket.react_bucket]
}

# Disable public access block for the S3 bucket
resource "aws_s3_bucket_public_access_block" "react_bucket_public_access_block" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public read access policy for the S3 bucket
data "aws_iam_policy_document" "get_object_iam_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.react_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

# Attach the policy to the S3 bucket
resource "aws_s3_bucket_policy" "react_bucket_policy" {
  bucket     = aws_s3_bucket.react_bucket.id
  policy     = data.aws_iam_policy_document.get_object_iam_policy.json
  depends_on = [aws_s3_bucket_public_access_block.react_bucket_public_access_block]
}

######################################################
#Networking for RDS (Default VPC + Security Group)

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "stock_news_analyzer_db_subnet_group" {
  name       = "stock-news-analyzer-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "Stock News Analyzer DB Subnet Group"
  }
}

# Security Group for RDS
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_security_group" "rds_sg" {
  name        = "stock-news-analyzer-rds-sg"
  description = "Allow MySQL access from your IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Stock News Analyzer RDS Security Group"
  }
}

# RDS Instance
variable "db_username" {
  type        = string
  description = "Database admin username"
}

variable "db_password" {
  type        = string
  description = "Database admin password"
  sensitive   = true
}

resource "aws_db_instance" "stock_news_analyzer_db" {
  identifier             = "stock-news-analyzer-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "stocknewsanalyzerdb"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.stock_news_analyzer_db_subnet_group.name
  publicly_accessible    = false

  tags = {
    Name = "Stock News Analyzer RDS"
  }
}
