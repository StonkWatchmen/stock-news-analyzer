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

variable "alpha_vantage_key" {
  type        = string
  sensitive   = true
  description = "Alpha Vantage API key"
}