# Use the existing default VPC and its subnets instead of creating a new VPC
data "aws_vpc" "default" {
  default = true
}

# Get all default subnets in that default VPC 
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# DB Subnet Group 

resource "aws_db_subnet_group" "stock_news_analyzer_db_subnet_group" {

  name       = "stock_news_analyzer_db_subnet_group_default"
  subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)

  tags = {
    Name = "Stock News Analyzer DB Subnet Group (default VPC)"
  }

  lifecycle {
    create_before_destroy = true
  }
}