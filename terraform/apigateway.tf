resource "aws_api_gateway_rest_api" "stock-news-analyzer-api" {
  name        = "stock-news-analyzer-rest-api"
  description = "REST API for Stock News Analyzer"
}

resource "aws_api_gateway_resource" "stocks" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "stocks"
}

resource "aws_api_gateway_resource" "watchlist" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "watchlist"
}

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name            = "stock-news-analyzer-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.user_pool.arn]
  identity_source = "method.request.header.Authorization"
  depends_on      = [aws_cognito_user_pool.user_pool]
}

resource "aws_api_gateway_method" "get_stocks" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.stocks.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  depends_on    = [aws_api_gateway_authorizer.cognito_authorizer]
}

resource "aws_api_gateway_method" "get_watchlist" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.watchlist.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_watchlist" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.watchlist.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "delete_watchlist" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.watchlist.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_iam_role" "lambda_role" {
  name = "stock-news-analyzer-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  depends_on = [aws_iam_role.lambda_role]
}

resource "aws_iam_role_policy" "lambda_vpc_access" {
  name = "lambda-vpc-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*"
      }
    ]
  })

  depends_on = [aws_iam_role.lambda_role]
}


resource "aws_lambda_function" "get_stocks_lambda" {

  function_name = "get-stocks-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"

  filename = data.archive_file.get_stocks_zip.output_path

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
}

resource "aws_api_gateway_integration" "get_stocks_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.stocks.id
  http_method = aws_api_gateway_method.get_stocks.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_stocks_lambda.invoke_arn

  depends_on = [aws_lambda_function.get_stocks_lambda]
}

resource "aws_api_gateway_integration" "get_watchlist_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.watchlist.id
  http_method             = aws_api_gateway_method.get_watchlist.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_stocks_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "post_watchlist_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.watchlist.id
  http_method             = aws_api_gateway_method.post_watchlist.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_stocks_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "delete_watchlist_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.watchlist.id
  http_method             = aws_api_gateway_method.delete_watchlist.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_stocks_lambda.invoke_arn
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_stocks_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.stock-news-analyzer-api.execution_arn}/*/*"
}

resource "aws_lambda_function" "init_rds_lambda" {
  role = aws_iam_role.lambda_role.arn
  function_name = "init_rds_lambda"
  handler = "lambda_function.lambda_handler"
  runtime = "python3.12"
  filename = data.archive_file.init_zip.output_path

  environment {
    variables = {
      DB_HOST           = aws_db_instance.stock_news_analyzer_db.address
      DB_USER           = var.db_username
      DB_PASS           = var.db_password
      DB_NAME           = "stocknewsanalyzerdb"
      DB_PORT           = "3306"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

resource "aws_lambda_function" "init_db_lambda" {

  function_name = "init-db-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"

  filename = data.archive_file.init_zip.output_path

  environment {
    variables = {
      DB_HOST           = aws_db_instance.stock_news_analyzer_db.address
      DB_USER           = var.db_username
      DB_PASS           = var.db_password
      DB_NAME           = "stocknewsanalyzerdb"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}


resource "aws_api_gateway_resource" "init_rds_resource" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "init_database"
}

resource "aws_api_gateway_method" "init_rds_method" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.init_rds_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "init_rds_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.init_rds_resource.id
  http_method             = aws_api_gateway_method.init_rds_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.init_rds_lambda.invoke_arn
}


# # --- IAM Role for EventBridge Scheduler ---
# resource "aws_iam_role" "scheduler_role" {
#   name = "lambda-scheduler-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "scheduler.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# # --- IAM Policy allowing Scheduler to invoke Lambda ---
# resource "aws_iam_role_policy" "scheduler_policy" {
#   name = "scheduler-invoke-lambda"
#   role = aws_iam_role.scheduler_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = "lambda:InvokeFunction"
#       Resource = aws_lambda_function..arn
#     }]
#   })
# }

# // creates AWS Eventbridge Scheduler
# resource "aws_scheduler_schedule" "lambda_schedule" {
#   name       = "invoke-collections-every-hour"
#   description = "Triggers Lambda every hour"

#   flexible_time_window {
#     mode = "OFF"
#   }

#   schedule_expression = "rate(1 hour)"

#   target {
#     arn      = aws_lambda_function.get_stocks_lambda.arn
#     role_arn = aws_iam_role.scheduler_role.arn

#     # Optional payload to Lambda
#     input = jsonencode({
#       action = "run_check"
#     })
#   }
# }