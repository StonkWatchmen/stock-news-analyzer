output "website_url" {
  value = aws_s3_bucket_website_configuration.react_bucket_website_config.website_endpoint
}
