resource "aws_sns_topic" "notifications" {
  name = "hourly-updates"
}

resource "aws_sns_topic_subscription" "user" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = "dg@catorcini.com"
}

