# main.tf

# ----------------------------------------------------
# 1. PROVIDER AND BACKEND CONFIGURATION
# ----------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Set your desired region
}

# 1. IAM Role Definition
resource "aws_iam_role" "ec2_s3_readonly_role" {
  name               = "EC2-S3-ReadOnly-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # This specifies the service that can assume the role (EC2 service)
          Service = "ec2.amazonaws.com" 
        }
      },
    ]
  })

  tags = {
    Name = "EC2 ReadOnly Role"
  }
}

# 2. Attach a Managed Policy (Permissions)
# This example attaches the standard AWS ReadOnlyAccess policy.
resource "aws_iam_role_policy_attachment" "s3_read_attach" {
  role       = aws_iam_role.ec2_s3_readonly_role.name
  
  # The ARN of the AWS managed policy for S3 Read Only access
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" 
}

# 3. IAM Instance Profile (Required to attach the role to an EC2 instance)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2-S3-ReadOnly-Profile"
  role = aws_iam_role.ec2_s3_readonly_role.name
}
