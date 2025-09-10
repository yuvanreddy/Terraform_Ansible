variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_count" {
  type    = number
  default = 3
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Windows Administrator password for initial setup if needed (optional)."
}

# If you want terraform to upload the installer, point to local file path relative to module
variable "local_installer_path" {
  type    = string
  default = "" # e.g. "../files/OpenJDK21U-jdk_x64_windows_hotspot_21.0.8_9.exe"
}
