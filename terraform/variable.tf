variable "project_name" {
  type    = string
  default = "stock-news-analyzer"
}



variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
