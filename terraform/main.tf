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

  lambda_config {
    post_confirmation = aws_lambda_function.add_user.arn
  }

  depends_on = [aws_lambda_function.add_user]
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
      rm -rf ${path.module}/build/get_stocks
      mkdir -p ${path.module}/build/get_stocks
      cp ${path.module}/lambda/get_stocks/handler.py ${path.module}/build/get_stocks/
      pip install -r ${path.module}/lambda/get_stocks/requirements.txt -t ${path.module}/build/get_stocks/
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "package_lambda_init" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build/init_rds 
      mkdir -p ${path.module}/build/init_rds/sql 
      cp -r ${path.module}/lambda/init_rds/sql/ ${path.module}/build/init_rds/sql/   
      cp ${path.module}/lambda/init_rds/handler.py ${path.module}/build/init_rds/ 
      pip install -r ${path.module}/lambda/init_rds/requirements.txt -t ${path.module}/build/init_rds/
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "package_lambda_notifs" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build/attach_notifs
      mkdir -p ${path.module}/build/attach_notifs
      cp -r ${path.module}/lambda/attach_notifs/* ${path.module}/build/attach_notifs
      cp ${path.module}/lambda/attach_notifs/handler.py ${path.module}/build/attach_notifs/
      pip install -r ${path.module}/lambda/attach_notifs/requirements.txt -t ${path.module}/build/attach_notifs/
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

# ========================================
# Backfill EC2 Instance
# ========================================

# Security group for backfill EC2
resource "aws_security_group" "backfill_sg" {
  name        = "stock-news-analyzer-backfill-sg"
  description = "Security group for backfill EC2 instance"
  vpc_id      = aws_vpc.stock_news_analyzer_vpc.id

  # Allow outbound to internet (for Alpha Vantage API)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound to RDS
  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_sg.id]
  }

  tags = {
    Name = "stock-news-analyzer-backfill-sg"
  }
}

# Update RDS security group to allow backfill EC2
resource "aws_security_group_rule" "rds_from_backfill" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.backfill_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}

# IAM role for backfill EC2
resource "aws_iam_role" "backfill_role" {
  name = "stock-news-analyzer-backfill-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach Comprehend policy to backfill role
resource "aws_iam_role_policy" "backfill_comprehend" {
  name = "backfill-comprehend-and-s3-access"
  role = aws_iam_role.backfill_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment",
          "comprehend:BatchDetectSentiment",
          "comprehend:DetectKeyPhrases",
          "comprehend:BatchDetectKeyPhrases"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backfill_scripts.arn,                    # bucket itself for ListBucket
          "${aws_s3_bucket.backfill_scripts.arn}/*"             # all objects in bucket for GetObject
        ]
      }
    ]
  })
}

# IAM instance profile
resource "aws_iam_instance_profile" "backfill_profile" {
  name = "stock-news-analyzer-backfill-profile"
  role = aws_iam_role.backfill_role.name
}

# Prepare user data script (small, downloads from S3)
data "template_file" "backfill_user_data" {
  template = file("${path.module}/scripts/user_data.sh")

  vars = {
    S3_BUCKET         = aws_s3_bucket.backfill_scripts.id
    DB_HOST           = aws_db_instance.stock_news_analyzer_db.address
    DB_USER           = var.db_username
    DB_PASS           = var.db_password
    DB_NAME           = "stocknewsanalyzerdb"
    ALPHA_VANTAGE_KEY = var.alpha_vantage_key
    AWS_REGION        = var.aws_region
  }
}

resource "aws_instance" "backfill_instance" {
  ami                    = data.aws_ami.amazonlinux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.backfill_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.backfill_profile.name

  user_data = data.template_file.backfill_user_data.rendered

  tags = {
    Name = "stock-news-analyzer-backfill"
  }

  instance_initiated_shutdown_behavior = "terminate"
}

# Create S3 bucket to host scripts
resource "aws_s3_bucket" "backfill_scripts" {
  bucket        = "stock-news-backfill-scripts-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "BackfillScripts"
    Environment = "Prod"
  }
}

# Upload Python script
resource "aws_s3_object" "backfill_script" {
  bucket = aws_s3_bucket.backfill_scripts.id
  key = "backfill_data.py"
  source = "${path.module}/scripts/backfill_data.py"
}

# Upload requirements.txt
resource "aws_s3_object" "requirements" {
  bucket = aws_s3_bucket.backfill_scripts.id
  key = "requirements.txt"
  source = "${path.module}/scripts/requirements.txt"
}
