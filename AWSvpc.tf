# --- Configuration and Provider Block ---
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Set your desired region
}


# --- 1. Virtual Private Cloud (VPC) ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Project-Main-VPC"
  }
}

# --- 2. Internet Gateway (IGW) ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Project-IGW"
  }
}


# --- 3. Public Subnet and NAT Gateway Setup ---

# 3a. Public Subnet 
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true         # Assigns public IPs to instances

  tags = {
    Name = "Project-Public-Subnet"
  }
}

# 3b. Elastic IP (EIP) for the NAT Gateway (Note: 'vpc = true' is deprecated and removed)
resource "aws_eip" "nat" {
  tags = {
    Name = "Project-NAT-EIP"
  }
}

# 3c. NAT Gateway (Placed in the Public Subnet)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.gw] 

  tags = {
    Name = "Project-NAT-GW"
  }
}

# --- 4. Private Subnet ---

# Private Subnet (Must be in the same AZ as the NAT GW)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a" 
  map_public_ip_on_launch = false

  tags = {
    Name = "Project-Private-Subnet"
  }
}


# --- 5. Route Tables and Associations ---

# 5a. Public Route Table (Routes 0.0.0.0/0 to the IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Project-Public-RT"
  }
}

# 5b. Private Route Table (Routes 0.0.0.0/0 through the NAT GW)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Project-Private-RT"
  }
}

# 5c. Associate Route Tables with Subnets
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


# --- 6. Security Groups (Essential Firewalls) ---

# 6a. Security Group for Public Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-host-sg"
  description = "Allow SSH inbound only for administration"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Restrict this to your actual public IP!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion-SG"
  }
}

# 6b. Security Group for Private Application Servers
resource "aws_security_group" "app_sg" {
  name        = "application-server-sg"
  description = "Allows inbound traffic only from trusted sources"
  vpc_id      = aws_vpc.main.id

  # Inbound Rule 1: Allow SSH (Port 22) ONLY from the Bastion Security Group
  ingress {
    description     = "Allow SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  
  # Inbound Rule 2: Allow HTTP (Port 80) from within the VPC (e.g., from a Load Balancer)
  ingress {
    description = "Allow HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Outbound traffic uses NAT Gateway
  }

  tags = {
    Name = "Application-SG"
  }
}
