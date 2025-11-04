output "website_url" {
  value = "http://${aws_s3_bucket.react_bucket.bucket}.s3-website-${aws_s3_bucket.react_bucket.region}.amazonaws.com"
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.app_client.id
}

output "cognito_domain" {
  value = aws_cognito_user_pool_domain.auth_domain.domain
}
