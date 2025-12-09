# ========================================
# API Gateway REST API
# ========================================
resource "aws_api_gateway_rest_api" "stock-news-analyzer-api" {
  name        = "stock-news-analyzer-rest-api"
  description = "REST API for Stock News Analyzer"
}

# ========================================
# API Gateway Resources
# ========================================
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

resource "aws_api_gateway_resource" "quotes" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "quotes"
}

resource "aws_api_gateway_resource" "notify" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "notify"
}

resource "aws_api_gateway_resource" "pulldown" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "pulldown"
}

# ========================================
# Cognito Authorizer
# ========================================
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name            = "stock-news-analyzer-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.user_pool.arn]
  identity_source = "method.request.header.Authorization"
  depends_on      = [aws_cognito_user_pool.user_pool]
}

# ========================================
# API Gateway Methods - /stocks
# ========================================
resource "aws_api_gateway_method" "get_stocks" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.stocks.id
  http_method   = "GET"
  authorization = "NONE"  # Changed from "COGNITO_USER_POOLS" - stocks list should be public
}

resource "aws_api_gateway_method" "stocks_options" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.stocks.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ========================================
# API Gateway Methods - /watchlist
# ========================================
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

resource "aws_api_gateway_method" "watchlist_options" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.watchlist.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ========================================
# API Gateway Methods - /quotes
# ========================================
resource "aws_api_gateway_method" "get_quotes" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.quotes.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "quotes_options" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.quotes.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ========================================
# API Gateway Methods - /notify
# ========================================
resource "aws_api_gateway_method" "post_notify" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.notify.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "notify_options" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.notify.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ========================================
# API Gateway Methods - /pulldown
# ========================================
resource "aws_api_gateway_method" "get_pulldown" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.pulldown.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "pulldown_options" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.pulldown.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ========================================
# IAM Role for Lambda
# ========================================
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

# ========================================
# Lambda Functions
# ========================================
resource "aws_lambda_function" "get_stocks_lambda" {
  function_name = "get-stocks-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout = 15
  filename         = data.archive_file.get_stocks_zip.output_path
  source_code_hash = data.archive_file.get_stocks_zip.output_base64sha256

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

resource "aws_lambda_function" "init_db_lambda" {
  function_name = "init-db-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout = 60 
  filename         = data.archive_file.init_rds_zip.output_path
  source_code_hash = data.archive_file.init_rds_zip.output_base64sha256

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

# ========================================
# Lambda Integrations - /stocks
# ========================================
resource "aws_api_gateway_integration" "get_stocks_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.stocks.id
  http_method             = aws_api_gateway_method.get_stocks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_stocks_lambda.invoke_arn

  depends_on = [aws_lambda_function.get_stocks_lambda]
}

resource "aws_api_gateway_integration" "stocks_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.stocks.id
  http_method = aws_api_gateway_method.stocks_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# ========================================
# Lambda Integrations - /watchlist
# ========================================
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

resource "aws_api_gateway_integration" "watchlist_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.watchlist.id
  http_method = aws_api_gateway_method.watchlist_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# ========================================
# Lambda Integrations - /quotes
# ========================================
resource "aws_api_gateway_integration" "get_quotes_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.quotes.id
  http_method             = aws_api_gateway_method.get_quotes.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_stocks_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "quotes_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.quotes.id
  http_method = aws_api_gateway_method.quotes_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# ========================================
# Lambda Integrations - /pulldown
# ========================================
resource "aws_api_gateway_integration" "get_pulldown_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.pulldown.id
  http_method             = aws_api_gateway_method.get_pulldown.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.scheduler_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "pulldown_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.pulldown.id
  http_method = aws_api_gateway_method.pulldown_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# ========================================
# Lambda Integrations - /notify
# ========================================
resource "aws_api_gateway_integration" "post_notify_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.notify.id
  http_method             = aws_api_gateway_method.post_notify.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.test_notifs_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "notify_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.notify.id
  http_method = aws_api_gateway_method.notify_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# ========================================
# CORS Method Responses - /stocks
# ========================================
resource "aws_api_gateway_method_response" "stocks_options_200" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.stocks.id
  http_method = aws_api_gateway_method.stocks_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "stocks_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.stocks.id
  http_method = aws_api_gateway_method.stocks_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [aws_api_gateway_integration.stocks_options]
}

# ========================================
# CORS Method Responses - /watchlist
# ========================================
resource "aws_api_gateway_method_response" "watchlist_options_200" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.watchlist.id
  http_method = aws_api_gateway_method.watchlist_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "watchlist_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.watchlist.id
  http_method = aws_api_gateway_method.watchlist_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [aws_api_gateway_integration.watchlist_options]
}

# ========================================
# CORS Method Responses - /notify
# ========================================
resource "aws_api_gateway_method_response" "notify_options_200" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.notify.id
  http_method = aws_api_gateway_method.notify_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Method response for POST /notify to allow CORS headers
resource "aws_api_gateway_method_response" "post_notify_200" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.notify.id
  http_method = aws_api_gateway_method.post_notify.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_method_response" "post_notify_500" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.notify.id
  http_method = aws_api_gateway_method.post_notify.http_method
  status_code = "500"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "notify_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.notify.id
  http_method = aws_api_gateway_method.notify_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [aws_api_gateway_integration.notify_options]
}

# Method response for POST /notify to allow CORS headers
resource "aws_api_gateway_method_response" "get_pulldown_200" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.pulldown.id
  http_method = aws_api_gateway_method.get_pulldown.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_method_response" "get_pulldown_500" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.pulldown.id
  http_method = aws_api_gateway_method.get_pulldown.http_method
  status_code = "500"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "pulldown_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.pulldown.id
  http_method = aws_api_gateway_method.pulldown_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [aws_api_gateway_integration.pulldown_options]
}

# ========================================
# CORS Method Responses - /quotes
# ========================================
resource "aws_api_gateway_method_response" "quotes_options_200" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.quotes.id
  http_method = aws_api_gateway_method.quotes_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "quotes_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.quotes.id
  http_method = aws_api_gateway_method.quotes_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [aws_api_gateway_integration.quotes_options]
}

# ========================================
# Lambda Permissions
# ========================================
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_stocks_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.stock-news-analyzer-api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_test_notifs" {
  statement_id  = "AllowAPIGatewayInvokeTestNotifs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_notifs_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.stock-news-analyzer-api.execution_arn}/*/*"
}

# ========================================
# API Gateway Deployment
# ========================================
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.stocks.id,
      aws_api_gateway_resource.watchlist.id,
      aws_api_gateway_resource.quotes.id,
      aws_api_gateway_resource.stock_history.id,  # ADD THIS
      aws_api_gateway_resource.notify.id,
      aws_api_gateway_resource.pulldown.id,
      
      aws_api_gateway_method.get_stocks.id,
      aws_api_gateway_method.get_watchlist.id,
      aws_api_gateway_method.post_watchlist.id,
      aws_api_gateway_method.delete_watchlist.id,
      aws_api_gateway_method.get_quotes.id,
      aws_api_gateway_method.get_stock_history.id,  # ADD THIS
      aws_api_gateway_method.post_notify.id,
      aws_api_gateway_method.stocks_options.id,
      aws_api_gateway_method.watchlist_options.id,
      aws_api_gateway_method.quotes_options.id,
      aws_api_gateway_method.stock_history_options.id,  # ADD THIS
      aws_api_gateway_method.notify_options.id,
      aws_api_gateway_method.get_pulldown.id,
      aws_api_gateway_method.pulldown_options.id,

      aws_api_gateway_method_response.post_notify_200.id,
      aws_api_gateway_method_response.post_notify_500.id,
      aws_api_gateway_method_response.get_pulldown_200.id,
      aws_api_gateway_method_response.get_pulldown_500.id,

      aws_api_gateway_integration.get_stocks_lambda_integration.id,
      aws_api_gateway_integration.get_watchlist_lambda_integration.id,
      aws_api_gateway_integration.post_watchlist_lambda_integration.id,
      aws_api_gateway_integration.delete_watchlist_lambda_integration.id,
      aws_api_gateway_integration.get_quotes_lambda_integration.id,
      aws_api_gateway_integration.get_stock_history_lambda_integration.id,  # ADD THIS
      aws_api_gateway_integration.post_notify_lambda_integration.id,
      aws_api_gateway_integration.get_pulldown_lambda_integration.id,

      aws_api_gateway_integration.notify_options.id,
      aws_api_gateway_integration.stocks_options.id,
      aws_api_gateway_integration.watchlist_options.id,
      aws_api_gateway_integration.quotes_options.id,
      aws_api_gateway_integration.stock_history_options.id,  # ADD THIS
      aws_api_gateway_integration.pulldown_options.id,

    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get_stocks_lambda_integration,
    aws_api_gateway_integration.get_watchlist_lambda_integration,
    aws_api_gateway_integration.post_watchlist_lambda_integration,
    aws_api_gateway_integration.delete_watchlist_lambda_integration,
    aws_api_gateway_integration.get_quotes_lambda_integration,
    aws_api_gateway_integration.get_stock_history_lambda_integration,  # ADD THIS
    aws_api_gateway_integration.post_notify_lambda_integration,
    aws_api_gateway_integration.stocks_options,
    aws_api_gateway_integration.watchlist_options,
    aws_api_gateway_integration.quotes_options,
    aws_api_gateway_integration.stock_history_options,  # ADD THIS
    aws_api_gateway_integration.notify_options,
    aws_api_gateway_integration_response.stocks_options,
    aws_api_gateway_integration_response.watchlist_options,
    aws_api_gateway_integration_response.quotes_options,
    aws_api_gateway_integration_response.stock_history_options,  # ADD THIS
    aws_api_gateway_integration_response.notify_options,
    aws_api_gateway_method_response.post_notify_200,
    aws_api_gateway_method_response.post_notify_500,

    aws_api_gateway_integration.pulldown_options,
    aws_api_gateway_integration.get_pulldown_lambda_integration,
    aws_api_gateway_method_response.get_pulldown_200,
    aws_api_gateway_method_response.get_pulldown_500,
    aws_api_gateway_method.get_pulldown,
    aws_api_gateway_method.pulldown_options,
    aws_api_gateway_resource.pulldown,
  ]
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  stage_name    = "prod"
}

# ========================================
# API Gateway Resource - /stock-history
# ========================================
resource "aws_api_gateway_resource" "stock_history" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "stock-history"
}

# GET /stock-history?stock_id=1 or ?ticker=AAPL
resource "aws_api_gateway_method" "get_stock_history" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.stock_history.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "stock_history_options" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.stock_history.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ========================================
# Lambda Integration - /stock-history
# ========================================
resource "aws_api_gateway_integration" "get_stock_history_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id             = aws_api_gateway_resource.stock_history.id
  http_method             = aws_api_gateway_method.get_stock_history.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_stocks_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "stock_history_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.stock_history.id
  http_method = aws_api_gateway_method.stock_history_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# ========================================
# CORS Method Responses - /stock-history
# ========================================
resource "aws_api_gateway_method_response" "stock_history_options_200" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.stock_history.id
  http_method = aws_api_gateway_method.stock_history_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "stock_history_options" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id = aws_api_gateway_resource.stock_history.id
  http_method = aws_api_gateway_method.stock_history_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [aws_api_gateway_integration.stock_history_options]
}