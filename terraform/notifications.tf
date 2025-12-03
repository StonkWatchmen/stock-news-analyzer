resource "aws_ses_email_identity" "dev_email" {
  email = "aguo1223@gmail.com"
}

resource "aws_iam_role_policy" "lambda_ses_send" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "test_notifs_lambda" {
  function_name = "test-notifs-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout = 15
  filename         = data.archive_file.test_notifs_zip.output_path
  source_code_hash = data.archive_file.test_notifs_zip.output_base64sha256

  environment {
    variables = {
      DB_HOST           = aws_db_instance.stock_news_analyzer_db.address
      DB_USER           = var.db_username
      DB_PASS           = var.db_password
      DB_NAME           = "stocknewsanalyzerdb"

      DEV_EMAIL        = aws_ses_email_identity.dev_email.email
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

resource "null_resource" "package_lambda_test_notifs" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build/test_notifs
      mkdir -p ${path.module}/build/test_notifs/
      cp -r ${path.module}/lambda/test_notifs/* ${path.module}/build/test_notifs/
      cp ${path.module}/lambda/test_notifs/handler.py ${path.module}/build/test_notifs/
      pip install -r ${path.module}/lambda/test_notifs/requirements.txt -t ${path.module}/build/test_notifs/
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}