variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "environment" {
  description = "Github environment name for s3 buckets"
  type        = string
}
