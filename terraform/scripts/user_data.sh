#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting backfill EC2 instance setup..."

# Update system
yum update -y

# Install Python 3, pip, and AWS CLI
yum install -y python3 python3-pip git aws-cli

# Create working directory
mkdir -p /home/ec2-user/backfill
cd /home/ec2-user/backfill

# Download the backfill script from S3
echo "Downloading backfill script from S3..."
aws s3 cp s3://${SCRIPT_BUCKET}/backfill_data.py ./backfill_data.py

cat > requirements.txt << 'REQUIREMENTS'
pymysql
requests
boto3
REQUIREMENTS

# Install Python dependencies
pip3 install -r requirements.txt

# Set environment variables
export DB_HOST="${DB_HOST}"
export DB_USER="${DB_USER}"
export DB_PASS="${DB_PASS}"
export DB_NAME="${DB_NAME}"
export ALPHA_VANTAGE_KEY="${ALPHA_VANTAGE_KEY}"
export AWS_REGION="${AWS_REGION}"

# Run the backfill script
echo "Running backfill script..."
python3 backfill_data.py

# Send completion notification (optional)
echo "Backfill completed at $(date)" >> /tmp/backfill_complete.txt

# Shutdown instance after completion (optional - saves costs)
echo "Shutting down instance in 5 minutes..."
shutdown -h +5