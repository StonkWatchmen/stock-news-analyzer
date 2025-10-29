resource "random_id" "suffix" { byte_length = 4 }

resource "aws_s3_bucket" "dashboard" {
  bucket = "${var.project_name}-dash-${random_id.suffix.hex}"
  tags   = { Project = var.project_name }
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.dashboard.id
  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
}

output "s3_bucket_name"      { value = aws_s3_bucket.dashboard.bucket }
output "s3_website_endpoint" { value = aws_s3_bucket_website_configuration.site.website_endpoint }
