variable "project_name" {type = string default = "stock-news-analyzer"}

variable "alpha_vantage_api_key" {
  type = string
  sensitive = true
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
