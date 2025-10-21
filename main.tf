# Provider Configuration
# Specifies the AWS provider and region for Terraform to manage resources in.
provider "aws" {
  region = "us-east-1"
}

# S3 Bucket to store Terraform state
resource "aws_s3_bucket" "terraform_bucket" {
    bucket = "stock-news-analyzer-terraform-state-bucket"
    force_destroy = true

    tags = {
        Name = "Stock News Analyzer Terraform State Bucket"
    }
}

# S3 Bucket to host static website
resource "aws_s3_bucket" "website_bucket" {
    bucket = "stock-news-analyzer-website-bucket"
    force_destroy = true

    tags = {
        Name = "Stock News Analyzer Website Bucket"
    }
}