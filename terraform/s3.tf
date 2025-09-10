# terraform/s3.tf - modern S3 configuration

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "jdk_bucket" {
  bucket_prefix = "my-private-jdk-bucket-"
  force_destroy = false

  tags = {
    Name    = "jdk-installer-bucket"
    Purpose = "store-openjdk-installer"
  }
}

# Block public access using dedicated resource
resource "aws_s3_bucket_public_access_block" "jdk_bucket_block" {
  bucket = aws_s3_bucket.jdk_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption (SSE-S3) using dedicated resource
resource "aws_s3_bucket_server_side_encryption_configuration" "jdk_bucket_sse" {
  bucket = aws_s3_bucket.jdk_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Optional: upload a local installer into the bucket (only if local_installer_path provided)
resource "aws_s3_object" "jdk_installer" {
  count = var.local_installer_path == "" ? 0 : 1

  bucket = aws_s3_bucket.jdk_bucket.id
  key    = "installers/OpenJDK21U-jdk_x64_windows_hotspot_21.0.8_9.exe"
  source = var.local_installer_path
  etag   = filemd5(var.local_installer_path)

  server_side_encryption = "AES256"
}
