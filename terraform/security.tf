resource "aws_security_group" "rds_sg" {
  name_prefix = "stock-news-analyzer-rds-"
  description = "Allow MySQL access from Lambda and temporary admin from my IP"
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
    create_before_destroy = true
  }

  tags = {
    Name        = "stock-news-analyzer-rds-sg"
    Environment = local.env_tag_safe
  }
}


resource "aws_security_group" "lambda_sg" {
  name_prefix = "stock-news-analyzer-lambda-"
  description = "Lambda ENIs egress + talk to RDS"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "stock-news-analyzer-lambda-sg"
    Environment = local.env_tag_safe
  }
}


resource "aws_security_group_rule" "rds_in_from_lambda" {
  type                     = "ingress"
  description              = "MySQL from Lambda SG"
  security_group_id        = aws_security_group.rds_sg.id
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_sg.id
}

