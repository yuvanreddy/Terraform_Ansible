# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# S3 Configuration
variable "create_s3_bucket" {
  description = "Whether to create a new S3 bucket or use existing one"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Name of S3 bucket for JDK installers"
  type        = string
  default     = "jdk-installers-bucket"
}

variable "local_installer_path" {
  description = "Local path to JDK installer file"
  type        = string
  default     = ""
}

# VPC Configuration
variable "create_vpc" {
  description = "Whether to create a new VPC or use existing one"
  type        = bool
  default     = true
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "jdk-deployment-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Security Group Configuration
variable "create_security_group" {
  description = "Whether to create a new security group or use existing one"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = "windows-jdk-sg"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change this to your IP range for security
}

# EC2 Configuration
variable "create_instances" {
  description = "Whether to create EC2 instances"
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "Number of Windows instances to create"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "instance_name_prefix" {
  description = "Prefix for instance names"
  type        = string
  default     = "windows-jdk-server"
}

variable "key_pair_name" {
  description = "Name of AWS key pair for EC2 access"
  type        = string
  default     = "my-keypair"  # Change this to your key pair name
}

variable "admin_password" {
  description = "Windows Administrator password for initial setup"
  type        = string
  default     = "TempPass123!"
  sensitive   = true
}

# Storage Configuration
variable "volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 50
}