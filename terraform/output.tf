output "website_url" {
  value = aws_s3_bucket_website_configuration.react_bucket_website_config.website_endpoint
}
# output "lambda_url" {
#   value = aws_db_instance.stock_news_analyzer_db
# }
