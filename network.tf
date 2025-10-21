# VPC and Networking Resources
# Create a VPC, subnets, and related networking infrastructure for WordPress.

# VPC
resource "aws_vpc" "stock_news_analyzer_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "Stock News Analyzer VPC"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.stock_news_analyzer_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Stock News Analyzer Public Subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.stock_news_analyzer_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Stock News Analyzer Private Subnet"
  }
}

# Internet Gateway for Public Access
resource "aws_internet_gateway" "stock_news_analyzer_igw" {
  vpc_id = aws_vpc.stock_news_analyzer_vpc.id
  tags = {
    Name = "Stock News Analyzer Internet Gateway"
  }
}
# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.stock_news_analyzer_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.stock_news_analyzer_igw.id
  }
  tags = {
    Name = "Stock News Analyzer Public Route Table"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# DB Subnet Group
resource "aws_db_subnet_group" "stock_news_analyzer_db_subnet_group" {
  name       = "stock_news_analyzer_db_subnet_group"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.public_subnet.id]

  tags = {
    Name = "Stock News Analyzer DB Subnet Group"
  }
}
