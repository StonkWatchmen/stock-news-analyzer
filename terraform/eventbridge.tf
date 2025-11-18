
# ========================================
# Scheduler Lambda - Runs every hour
# ========================================

# Package the scheduler Lambda
resource "null_resource" "package_lambda_scheduler" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build/scheduler
      mkdir -p ${path.module}/build/scheduler
      cp ${path.module}/lambda/scheduler/handler.py ${path.module}/build/scheduler/
      if [ -f ${path.module}/lambda/scheduler/requirements.txt ]; then
        pip install -r ${path.module}/lambda/scheduler/requirements.txt -t ${path.module}/build/scheduler/
      fi
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

# Scheduler Lambda Function
resource "aws_lambda_function" "scheduler_lambda" {
  function_name = "stock-news-analyzer-scheduler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.scheduler_zip.output_path
  source_code_hash = data.archive_file.scheduler_zip.output_base64sha256

  environment {
    variables = {
      DB_HOST           = aws_db_instance.stock_news_analyzer_db.address
      DB_USER           = var.db_username
      DB_PASS           = var.db_password
      DB_NAME           = "stocknewsanalyzerdb"
      ALPHA_VANTAGE_KEY = var.alpha_vantage_key
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  timeout     = 300
  memory_size = 256
}

# ========================================
# EventBridge Scheduler Configuration
# ========================================

# IAM Role for EventBridge Scheduler
resource "aws_iam_role" "scheduler_role" {
  name = "stock-news-analyzer-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy allowing Scheduler to invoke Lambda
resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "scheduler-invoke-lambda"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.scheduler_lambda.arn
    }]
  })
}

# EventBridge Scheduler - Runs every hour
resource "aws_scheduler_schedule" "lambda_hourly_schedule" {
  name        = "stock-news-analyzer-hourly"
  description = "Triggers scheduler Lambda every hour to update stock prices"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(1 hour)"

  target {
    arn      = aws_lambda_function.scheduler_lambda.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      source = "eventbridge-scheduler"
      action = "update_all_prices"
    })
  }
}
