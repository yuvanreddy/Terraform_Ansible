# Configure Terraform and providers
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  # Use S3 backend for state management (prevents resource recreation)
  backend "s3" {
    bucket         = "terraform-state-jdk-deployment"  # Change this to your unique bucket name
    key            = "jdk-deployment/terraform.tfstate"
    region         = "us-east-1"  # Change to your preferred region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data source to check if S3 bucket already exists
data "aws_s3_bucket" "existing_bucket" {
  bucket = var.s3_bucket_name
  count  = var.create_s3_bucket ? 0 : 1
}

# Data source to get existing VPC (if not creating new one)
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Data source to get existing subnets
data "aws_subnets" "existing" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
}

# Data source to get existing security group
data "aws_security_group" "existing_sg" {
  count = var.create_security_group ? 0 : 1
  
  filter {
    name   = "group-name"
    values = [var.security_group_name]
  }
  
  filter {
    name   = "vpc-id"
    values = [var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id]
  }
}

# Random suffix for unique resource names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for JDK installer (create only if doesn't exist)
resource "aws_s3_bucket" "jdk_installers" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = "${var.s3_bucket_name}-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "JDK Installers"
    Environment = var.environment
    Purpose     = "Store JDK installation files"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "jdk_installers_versioning" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.jdk_installers[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "jdk_installers_encryption" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.jdk_installers[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "jdk_installers_pab" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.jdk_installers[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload JDK installer to S3 (only if file exists and bucket is created)
resource "aws_s3_object" "jdk_installer" {
  count = var.local_installer_path != "" && fileexists(var.local_installer_path) ? 1 : 0
  
  bucket = var.create_s3_bucket ? aws_s3_bucket.jdk_installers[0].bucket : var.s3_bucket_name
  key    = "installers/${basename(var.local_installer_path)}"
  source = var.local_installer_path
  etag   = filemd5(var.local_installer_path)
  
  tags = {
    Name        = "JDK Installer"
    Environment = var.environment
  }
}

# VPC (create only if specified)
resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0
  
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = var.vpc_name
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count = var.create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  tags = {
    Name        = "${var.vpc_name}-igw"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  count = var.create_vpc ? length(var.availability_zones) : 0
  
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.vpc_name}-public-${count.index + 1}"
    Environment = var.environment
    Type        = "Public"
  }
}

# Route Table
resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
  
  tags = {
    Name        = "${var.vpc_name}-public-rt"
    Environment = var.environment
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  count = var.create_vpc ? length(aws_subnet.public) : 0
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Security Group
resource "aws_security_group" "windows_sg" {
  count = var.create_security_group ? 1 : 0
  
  name_prefix = "${var.security_group_name}-"
  vpc_id      = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id
  
  # RDP access
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "RDP access"
  }
  
  # WinRM HTTP
  ingress {
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "WinRM HTTP"
  }
  
  # WinRM HTTPS
  ingress {
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "WinRM HTTPS"
  }
  
  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = {
    Name        = var.security_group_name
    Environment = var.environment
  }
}

# Data source for latest Windows Server AMI
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for EC2 instances (for SSM access)
resource "aws_iam_role" "ec2_ssm_role" {
  count = var.create_instances ? 1 : 0
  
  name_prefix = "EC2-SSM-Role-"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "EC2-SSM-Role"
    Environment = var.environment
  }
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  count = var.create_instances ? 1 : 0
  
  role       = aws_iam_role.ec2_ssm_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.create_instances ? 1 : 0
  
  name_prefix = "EC2-SSM-Profile-"
  role        = aws_iam_role.ec2_ssm_role[0].name
  
  tags = {
    Name        = "EC2-SSM-Profile"
    Environment = var.environment
  }
}

# EC2 Instances (create only if specified)
resource "aws_instance" "windows_servers" {
  count = var.create_instances ? var.instance_count : 0
  
  ami                     = data.aws_ami.windows.id
  instance_type           = var.instance_type
  key_name                = var.key_pair_name
  vpc_security_group_ids  = [var.create_security_group ? aws_security_group.windows_sg[0].id : data.aws_security_group.existing_sg[0].id]
  subnet_id               = var.create_vpc ? aws_subnet.public[count.index % length(aws_subnet.public)].id : tolist(data.aws_subnets.existing[0].ids)[count.index % length(data.aws_subnets.existing[0].ids)]
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile[0].name
  
  # User data for initial setup
  user_data = base64encode(templatefile("${path.module}/userdata.ps1", {
    admin_password = var.admin_password
  }))
  
  # Root volume
  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name        = "${var.instance_name_prefix}-${count.index + 1}-root"
      Environment = var.environment
    }
  }
  
  tags = {
    Name        = "${var.instance_name_prefix}-${count.index + 1}"
    Environment = var.environment
    Purpose     = "JDK Installation Target"
    OS          = "Windows Server 2022"
  }
  
  # Ensure instance is ready before proceeding
  lifecycle {
    create_before_destroy = true
  }
}