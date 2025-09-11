# AWS Configuration
aws_region = "us-east-1"
environment = "dev"

# Resource Creation Flags
create_s3_bucket = true        # Set to false if you want to use existing bucket
create_vpc = true             # Set to false if you want to use existing VPC
create_security_group = true  # Set to false if you want to use existing security group
create_instances = true       # Set to false if you don't want to create instances

# S3 Configuration
s3_bucket_name = "jdk-installers-bucket"  # Change to your preferred bucket name
local_installer_path = ""  # Will be set by GitHub Actions

# VPC Configuration
vpc_name = "jdk-deployment-vpc"
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Security Configuration
security_group_name = "windows-jdk-sg"
allowed_cidr_blocks = ["0.0.0.0/0"]  # CHANGE THIS TO YOUR IP RANGE FOR SECURITY

# EC2 Configuration
instance_count = 2
instance_type = "t3.medium"
instance_name_prefix = "windows-jdk-server"
key_pair_name = "my-keypair"  # CHANGE THIS TO YOUR KEY PAIR NAME
admin_password = "TempPass123!"  # This will be overridden by GitHub secret

# Storage Configuration
volume_type = "gp3"
volume_size = 50