output "website_url" {
  value = "http://${aws_s3_bucket.react_bucket.bucket}.s3-website-${aws_s3_bucket.react_bucket.region}.amazonaws.com"
}