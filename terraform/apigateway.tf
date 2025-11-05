resource "aws_api_gateway_rest_api" "stock-news-analyzer-api" {
  name        = "stock-news-analyzer-rest-api"
  description = "REST API for Stock News Analyzer"
}

resource "aws_api_gateway_resource" "stocks" {
  rest_api_id = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  parent_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.root_resource_id
  path_part   = "stocks"
}

resource "aws_api_gateway_method" "get_stocks" {
  rest_api_id   = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  resource_id   = aws_api_gateway_resource.stocks.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
}

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                   = "stock-news-analyzer-cognito-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.stock-news-analyzer-api.id
  type                   = "COGNITO_USER_POOLS"
  provider_arns          = [aws_cognito_user_pool.user_pool.arn]
  identity_source         = "method.request.header.Authorization"
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
}

resource "aws_lambda_function" "get_stocks_lambda" {
  function_name = "get-stocks-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"

  filename      = data.archive_file.get_stocks_zip.output_path

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