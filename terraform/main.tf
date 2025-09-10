terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
    random = { source = "hashicorp/random" }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "this" {
  cidr_block = "10.10.0.0/16"
  tags       = { Name = "tf-ssm-vpc" }
}

resource "aws_subnet" "this" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "tf-ssm-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.rt.id
}

# Security group: we allow only outbound (so instances can reach SSM/S3)
resource "aws_security_group" "instance_sg" {
  name        = "ssm-windows-sg"
  description = "Allow outbound for SSM/S3 only (no inbound open)"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # No inbound rules => unreachable from internet for RDP/WinRM
}
