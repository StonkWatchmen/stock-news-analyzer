# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "stock_news_analyzer_rds_sg"
  description = "Security group for Stock News Analyzer RDS instance"
  vpc_id      = aws_vpc.stock_news_analyzer_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id, aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name   = "stock_news_analyzer_ec2_sg"
  vpc_id = aws_vpc.stock_news_analyzer_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "stock-news-analyzer-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.stock_news_analyzer_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "stock-news-analyzer-lambda-sg"
  }
}
