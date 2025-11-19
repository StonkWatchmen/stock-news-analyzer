resource "aws_sns_topic" "notifications" {
  name = "hourly-updates"
}

resource "aws_sns_topic_subscription" "user" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = "dg@catorcini.com"
}

resource "aws_lambda_function" "attach_notifs_lambda" {
  function_name = "attach-notifs-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout = 15
  filename         = data.archive_file.attach_notifs_zip.output_path
  source_code_hash = data.archive_file.attach_notifs_zip.output_base64sha256

  environment {
    variables = {
      DB_HOST           = aws_db_instance.stock_news_analyzer_db.address
      DB_USER           = var.db_username
      DB_PASS           = var.db_password
      DB_NAME           = "stocknewsanalyzerdb"

      NOTIFS_ARN        = aws_sns_topic.notifications.arn
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}