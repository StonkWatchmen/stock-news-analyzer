#!/bin/bash
yum update -y
yum install -y python3 python3-pip git awscli

mkdir -p /home/ec2-user/backfill
cd /home/ec2-user/backfill

# Download scripts from S3
aws s3 cp s3://${S3_BUCKET}/backfill_data.py ./backfill_data.py
aws s3 cp s3://${S3_BUCKET}/requirements.txt ./requirements.txt

# Install Python dependencies
pip3 install -r requirements.txt

# Set environment variables
export DB_HOST="${DB_HOST}"
export DB_USER="${DB_USER}"
export DB_PASS="${DB_PASS}"
export DB_NAME="${DB_NAME}"
export ALPHA_VANTAGE_KEY="${ALPHA_VANTAGE_KEY}"
export AWS_REGION="${AWS_REGION}"

# Run backfill
python3 backfill_data.py

# Terminate instance after completion
shutdown -h +5
