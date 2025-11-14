# Provider Configuration
# Specifies the AWS provider and region for Terraform to manage resources in.
provider "aws" {
  region = var.aws_region
}

# S3 Bucket to store Terraform state
resource "aws_s3_bucket" "terraform_bucket" {
  bucket        = "stock-news-analyzer-terraform-state-bucket-${var.environment}"
  force_destroy = true

  tags = {
    Name = "Stock News Analyzer Terraform State Bucket"
  }
}

# S3 Bucket to host static website
resource "aws_s3_bucket" "react_bucket" {
  bucket        = "stock-news-analyzer-react-app-bucket-${var.environment}"
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

  depends_on = [aws_s3_bucket.react_bucket]
}

resource "aws_s3_bucket_public_access_block" "react_bucket_public_access_block" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "react_bucket_policy" {
  bucket = aws_s3_bucket.react_bucket.id

  policy     = data.aws_iam_policy_document.get_object_iam_policy.json
  depends_on = [aws_s3_bucket_public_access_block.react_bucket_public_access_block]
}

# RDS Instance
resource "aws_db_instance" "stock_news_analyzer_db" {
  identifier             = "stock-news-analyzer-db"                                     # Unique identifier for the RDS instance
  allocated_storage      = 20                                                           # 20GB of storage
  storage_type           = "gp2"                                                        # General Purpose SSD
  engine                 = "mysql"                                                      # MySQL database engine
  engine_version         = "8.0"                                                        # MySQL version 8.0
  instance_class         = "db.t3.micro"                                                # Free tier eligible instance type
  db_name                = "stocknewsanalyzerdb"                                        # Name of the Stock News Analyzer database
  username               = var.db_username                                              # Database admin username
  password               = var.db_password                                              # Replace with a secure password
  parameter_group_name   = "default.mysql8.0"                                           # Default parameter group for MySQL 8.0
  skip_final_snapshot    = true                                                         # Skip final snapshot when destroying the database
  vpc_security_group_ids = [aws_security_group.rds_sg.id]                               # Attach the RDS security group
  db_subnet_group_name   = aws_db_subnet_group.stock_news_analyzer_db_subnet_group.name # Use the created subnet group
}

resource "aws_instance" "db_init" {
  ami                         = data.aws_ami.amazonlinux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  depends_on                  = [aws_db_instance.stock_news_analyzer_db]

  user_data = <<-EOF
    #!/bin/bash
    yum install -y mysql

    # Retry loop until DB is ready
    until mysql -h ${aws_db_instance.stock_news_analyzer_db.address} \
                -u ${var.db_username} \
                -p${var.db_password} \
                -e "SELECT 1" >/dev/null 2>&1; do
        sleep 5
    done

    mysql -h ${aws_db_instance.stock_news_analyzer_db.address} \
          -u ${var.db_username} \
          -p${var.db_password} \
          stocknewsanalyzerdb

    shutdown -h now
  EOF

  tags = {
    Name = "db-init"
  }
}


resource "aws_iam_role" "ec2_role" {
  name = "stock-news-analyzer-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_basic_execution" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  depends_on = [aws_iam_role.ec2_role]
}

resource "aws_cognito_user_pool" "user_pool" {
  name = "stock-news-analyzer-user-pool"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}
resource "aws_cognito_user_pool_client" "web_client" {
  name            = "stock-news-analyzer-client"
  user_pool_id    = aws_cognito_user_pool.user_pool.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]

  callback_urls = [
    "https://${aws_s3_bucket.react_bucket.bucket}.s3-website-${var.aws_region}.amazonaws.com"
  ]

  logout_urls = [
    "https://${aws_s3_bucket.react_bucket.bucket}.s3-website-${var.aws_region}.amazonaws.com"
  ]

  supported_identity_providers = ["COGNITO"]
}
resource "aws_cognito_user_pool_domain" "auth_domain" {
  domain       = "stock-news-analyzer-${var.environment}"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "null_resource" "package_lambda_stocks" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build
      mkdir -p ${path.module}/build
      cp ${path.module}/lambda/get_stocks/handler.py ${path.module}/build/
      pip install -r ${path.module}/lambda/get_stocks/requirements.txt -t ${path.module}/build/
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "package_lambda_init" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build
      mkdir -p ${path.module}/build/sql
      cp -r ${path.module}/lambda/init_rds/sql/* ${path.module}/build/sql/
      cp ${path.module}/lambda/init_rds/handler.py ${path.module}/build/
      pip install -r ${path.module}/lambda/init_rds/requirements.txt -t ${path.module}/build/
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}
