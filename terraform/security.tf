resource "aws_security_group" "rds_sg" {
  name_prefix = "stock-news-analyzer-rds-" # instead of fixed name
  description = "RDS access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Temporary admin from my IP"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true # safer on renames
  }

  tags = {
    Name        = "stock-news-analyzer-rds-sg"
    Environment = local.env_tag_safe
  }
}