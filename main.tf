# Provider Configuration
# Specifies the AWS provider and region for Terraform to manage resources in.
provider "aws" {
  region = "us-east-1"
}

# S3 Bucket
resource "aws_s3_bucket" "stonk_bucket" {
    bucket = "stonkwatchmen-stonk-bucket"

    tags = {
        Name = "Stonk Bucket"
    }
}