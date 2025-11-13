# Data source to fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "amazonlinux" {
  most_recent = true       # Get the most recent version of the AMI
  owners      = ["amazon"] # Filter AMIs owned by Amazon

  # Filter for Amazon Linux 2023 AMIs
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  # Ensure we get a hardware virtual machine
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Filter for EBS-backed instances
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  # Filter for x86_64 architecture
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

}

data "aws_iam_policy_document" "get_object_iam_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.react_bucket.arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}


data "archive_file" "get_stocks_zip" {
  depends_on  = [null_resource.package_lambda]
  type        = "zip"
  source_dir  = "${path.module}/build"
  output_path = "${path.module}/get_stocks.zip"
}

data "archive_file" "init_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/init_rds"
  output_path = "${path.module}/lambda_init_db.zip"
}