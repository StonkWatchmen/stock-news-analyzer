output "website_url" {
  value = aws_s3_bucket.react_bucket.website_endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.stock_news_analyzer_db.address
}