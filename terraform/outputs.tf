# S3 Bucket Outputs
output "s3_bucket" {
  description = "Name of the S3 bucket containing JDK installers"
  value       = var.create_s3_bucket ? aws_s3_bucket.jdk_installers[0].bucket : var.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = var.create_s3_bucket ? aws_s3_bucket.jdk_installers[0].arn : "arn:aws:s3:::${var.s3_bucket_name}"
}

output "s3_key" {
  description = "S3 key of the uploaded JDK installer (normalized to .msi)."

  # If Terraform created the aws_s3_object, return its actual key.
  # Otherwise return a computed default based on local_installer_path but normalize any .exe -> .msi.
  value = length(aws_s3_object.jdk_installer) > 0 ?
    aws_s3_object.jdk_installer[0].key :
    "installers/${replace(basename(var.local_installer_path), \".exe\", \".msi\")}"
}


# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].id : (length(data.aws_vpc.existing) > 0 ? data.aws_vpc.existing[0].id : null)
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = var.create_vpc ? aws_subnet.public[*].id : (length(data.aws_subnets.existing) > 0 ? data.aws_subnets.existing[0].ids : [])
}

# Security Group Outputs
output "security_group_id" {
  description = "ID of the security group"
  value       = var.create_security_group ? aws_security_group.windows_sg[0].id : (length(data.aws_security_group.existing_sg) > 0 ? data.aws_security_group.existing_sg[0].id : null)
}

# Instance Outputs
output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = var.create_instances ? aws_instance.windows_servers[*].id : []
}

output "instance_public_ips" {
  description = "List of public IP addresses of the instances"
  value       = var.create_instances ? aws_instance.windows_servers[*].public_ip : []
}

output "instance_private_ips" {
  description = "List of private IP addresses of the instances"
  value       = var.create_instances ? aws_instance.windows_servers[*].private_ip : []
}

output "instance_public_dns" {
  description = "List of public DNS names of the instances"
  value       = var.create_instances ? aws_instance.windows_servers[*].public_dns : []
}

# IAM Outputs
output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = var.create_instances ? aws_iam_role.ec2_ssm_role[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = var.create_instances ? aws_iam_instance_profile.ec2_profile[0].name : null
}

# Summary Output
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    s3_bucket      = var.create_s3_bucket ? aws_s3_bucket.jdk_installers[0].bucket : var.s3_bucket_name
    vpc_created    = var.create_vpc
    instances_created = var.create_instances ? length(aws_instance.windows_servers) : 0
    instance_ids   = var.create_instances ? aws_instance.windows_servers[*].id : []
    region         = var.aws_region
    environment    = var.environment
  }
}
