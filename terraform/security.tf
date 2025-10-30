# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "stock_news_analyzer_rds_sg"
  description = "Security group for Stock News Analyzer RDS instance"
  vpc_id      = aws_vpc.stock_news_analyzer_vpc.id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
  }
}
