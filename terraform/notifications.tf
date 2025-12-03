resource "aws_ses_email_identity" "dev_email" {
  email = "aguo1223@gmail.com"
}

resource "aws_iam_role_policy" "lambda_ses_send" {
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

