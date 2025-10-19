# Provider Configuration
# Specifies the AWS provider and region for Terraform to manage resources in.
provider "aws" {
  region = "us-east-1"
}

# S3 Bucket to store Terraform state
resource "aws_s3_bucket" "terraform_bucket" {
    bucket = "stonkwatchmen-terraform-bucket"

    tags = {
        Name = "Terraform Bucket"
    }
}

# S3 Bucket to host static website
resource "aws_s3_bucket" "website_bucket" {
    bucket = "stonkwatchmen-website-bucket"

    tags = {
        Name = "Website Bucket"
    }
}