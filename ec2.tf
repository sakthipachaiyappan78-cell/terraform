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

# ----------------------------------------------------
# 2. AWS KEY PAIR (REQUIRED FOR SSH ACCESS)
# ----------------------------------------------------
# This block creates a new key pair named "dev" in AWS using your public key.
resource "aws_key_pair" "deployer" {
  key_name   = "dev"
  
  # IMPORTANT: Replace the key content below with YOUR actual PUBLIC SSH KEY.
  # Using Heredoc (<<-EOT) fixes the multi-line string error.
  public_key = <<-EOT
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDh029/CFhN2OdChxznBIBuLjL/Ya648hXp
StbS/IJFOMvxrXEet1Scwcgf9xCcOEOQcZrwUVOe3MGsP+HNIcKvLN6VlDGoiu7i
nS4TCjXfO30C7BHt3YFEkOptsw+3xvORJrc6F3I6Xs+9dMoPEnI3zGawOD7+WeBR
oUXmRXwoT/RD3zUphd6Od20kHYr1hjqMC7k2nQ8HFTKIO75IKQdRNOS7bhwKzLjQ
Wtg0dGFjlG+NmCHawmR5vaZgmuEtAO8YlRpV6VzNFUTyndM7vX+Tm8eENC9Oktsj
goD3fG4eJDzQoQIPqYzWWF+19q5SdxFCnZ0NylVi20xK9a+WQ/l/
EOT
}

# ----------------------------------------------------
# 3. NETWORK DATA SOURCES (Find Default VPC/Subnets)
# ----------------------------------------------------
# Find the default VPC ID
data "aws_vpc" "default" {
  default = true
}

# Find subnets within the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ----------------------------------------------------
# 4. SECURITY GROUP (Firewall Rule)
# ----------------------------------------------------
resource "aws_security_group" "instance_sg" {
  name        = "ssh_access_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  # Allow Inbound SSH (Port 22) from all IPs (0.0.0.0/0)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Allow All Outbound Traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------------------------------
# 5. EC2 INSTANCE AND AMI DATA SOURCE
# ----------------------------------------------------
# Find the latest official Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Official Ubuntu Owner ID)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Launch the EC2 Instance
resource "aws_instance" "my_Project_server" {
  # Dynamically gets the latest Ubuntu AMI ID
  ami           = data.aws_ami.ubuntu.id 
  instance_type = "t2.micro" 
  
  # References the key pair created above
  key_name      = aws_key_pair.deployer.key_name 
  
  # Selects the first available subnet in the default VPC
  subnet_id = data.aws_subnets.default.ids[0]

  # Attach the Security Group
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # Enable public IP assignment
  associate_public_ip_address = true
  
  tags = {
    Name = "Terraform-Web-Server"
  }
}

# ----------------------------------------------------
# 6. OUTPUTS
# ----------------------------------------------------
output "instance_public_ip" {
  description = "The public IP address to SSH into the instance"
  value       = aws_instance.my_web_server.public_ip
}
