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
  depends_on  = [null_resource.package_lambda_stocks]
  type        = "zip"
  source_dir  = "${path.module}/build/get_stocks"
  output_path = "${path.module}/get_stocks.zip"
}

data "archive_file" "init_rds_zip" {
  depends_on  = [null_resource.package_lambda_init]
  type        = "zip"
  source_dir  = "${path.module}/build/init_rds"
  output_path = "${path.module}/init_rds.zip"
}

data "archive_file" "add_user_zip" {
  depends_on  = [null_resource.package_lambda_add_user]
  type        = "zip"
  source_dir  = "${path.module}/build/add_user"
  output_path = "${path.module}/add_user.zip"
}

data "archive_file" "get_users_zip" {
  depends_on  = [null_resource.package_lambda_add_user]
  type        = "zip"
  source_dir  = "${path.module}/build/get_users"
  output_path = "${path.module}/get_users.zip"
}

data "archive_file" "attach_notifs_zip" {
  depends_on = [null_resource.package_lambda_notifs]
  type        = "zip"
  source_dir  = "${path.module}/build/attach_notifs"
  output_path = "${path.module}/attach_notifs.zip"
}

# Create ZIP archive for scheduler Lambda
data "archive_file" "scheduler_zip" {
  depends_on  = [null_resource.package_lambda_scheduler]
  type        = "zip"
  source_dir  = "${path.module}/build/scheduler"
  output_path = "${path.module}/scheduler.zip"
}

data "archive_file" "test_notifs_zip" {
  depends_on = [null_resource.package_lambda_test_notifs]
  type        = "zip"
  source_dir  = "${path.module}/build/test_notifs"
  output_path = "${path.module}/test_notifs.zip"
}