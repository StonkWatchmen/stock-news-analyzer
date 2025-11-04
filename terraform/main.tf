
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


#DyanmoDB Write Access Policy & Attachment
data "aws_iam_policy_document" "ddb_write_doc" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.stock_news_table.arn]
  }
}

resource "aws_iam_policy" "ddb_write" {
  name   = "stock-news-analyzer-ddb-write-${var.environment}"
  policy = data.aws_iam_policy_document.ddb_write_doc.json
}

resource "aws_iam_role_policy_attachment" "ddb_write_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.ddb_write.arn
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



  # Environment variables used by Lambda code
  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.stock_news_table.name
      USE_COMPREHEND = "true"
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.comprehend_access,
    aws_iam_role_policy_attachment.ddb_write_attach
  ]


}

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.lambda_function.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["*"]
  }
}




########################################
# DYNAMODB TABLE
########################################

resource "aws_dynamodb_table" "stock_news_table" {
  name         = "stock-news-analyzer-table-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "symbol"
  range_key    = "created_at"

  attribute {
    name = "symbol"
    type = "S"
  }
  attribute {
    name = "created_at"
    type = "S"
  }
  tags = { Name = "Stock News Analyzer Table" }
}




########################################
# API Gateway for Lambda Function
resource "aws_apigatewayv2_api" "http_api" {
  name          = "stock-news-analyzer-api-${var.environment}"
  protocol_type = "HTTP"
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda_function.arn
  payload_format_version = "2.0"
}


# API Gateway Routes and Stage
resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "post_analyze" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /analyze"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}


resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowApiGwInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "api_base_url" {
  value       = aws_apigatewayv2_api.http_api.api_endpoint
  description = "Base URL for the HTTP API. POST to /analyze"
}

# S3 Buckets
###############################################
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
}

# IAM Policy for S3 Bucket Public Read Access
resource "aws_s3_bucket_public_access_block" "react_bucket_public_access_block" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}




# IAM Policy Document to allow public read access to S3 bucket objects
resource "aws_s3_bucket_policy" "react_bucket_policy" {
  bucket = aws_s3_bucket.react_bucket.id

  policy     = data.aws_iam_policy_document.get_object_iam_policy.json
  depends_on = [aws_s3_bucket_public_access_block.react_bucket_public_access_block]
}

######################################################

# Security Group for RDS
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# RDS Instance
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