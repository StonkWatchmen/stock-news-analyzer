
# Security group for RDS in the default VPC
resource "aws_security_group" "rds_sg" {
  name        = "stock_news_analyzer_rds_sg"
  description = "Security group for Stock News Analyzer RDS instance"
  vpc_id      = data.aws_vpc.default.id

  # Minimal/temporary rule: allow MySQL only from within the VPC CIDR

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
