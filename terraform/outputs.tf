output "instance_ids" {
  value = aws_instance.win.*.id
}

output "instance_public_ips" {
  value = aws_instance.win.*.public_ip
}

output "s3_bucket" {
  value = aws_s3_bucket.jdk_bucket.bucket
}

# Safe: return the full list of uploaded s3 keys (may be empty list)
# This avoids indexing or ternary operations that can cause syntax problems.
output "s3_key_list" {
  value       = aws_s3_object.jdk_installer.*.key
  description = "List of S3 keys uploaded by Terraform (may be empty)"
}
