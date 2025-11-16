resource "aws_lambda_function" "add_user" {
  function_name = "add-user"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.add_user_zip.output_path
  source_code_hash = data.archive_file.add_user_zip.output_base64sha256

  environment {
    variables = {
      DB_HOST = aws_db_instance.stock_news_analyzer_db.address
      DB_USER = var.db_username
      DB_PASS = var.db_password
      DB_NAME = "stocknewsanalyzerdb"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

resource "null_resource" "package_lambda_add_user" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/build/add_user
      mkdir -p ${path.module}/build/add_user/sql
      cp -r ${path.module}/lambda/add_user/sql/* ${path.module}/build/add_user/sql/
      cp ${path.module}/lambda/add_user/handler.py ${path.module}/build/add_user/
      pip install -r ${path.module}/lambda/add_user/requirements.txt -t ${path.module}/build/add_user/
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "aws_cognito_user_pool_lambda_config" "trigger" {
  user_pool_id      = aws_cognito_user_pool.user_pool.id
  post_confirmation = aws_lambda_function.add_user_lambda.arn
}

resource "aws_lambda_permission" "allow_cognito" {
  statement_id = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_user.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.user_pool.arn
}