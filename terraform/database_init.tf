# Lambda invocation to initialize database
resource "aws_lambda_invocation" "init_database" {
  function_name = aws_lambda_function.init_db_lambda.function_name

  input = jsonencode({
    action = "initialize_database"
  })

  depends_on = [
    aws_db_instance.stock_news_analyzer_db,
    aws_lambda_function.init_db_lambda
  ]


}