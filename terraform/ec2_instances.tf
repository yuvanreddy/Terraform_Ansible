data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base*"]
  }
}

resource "aws_instance" "win" {
  count                       = var.instance_count
  ami                         = data.aws_ami.windows.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.this.id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "ssm-win-${count.index + 1}"
  }

  # Optional: set admin password via user_data (if you want) - not necessary for SSM
  # user_data = <<-EOF
  # <powershell>
  # # set password or other bootstrap tasks
  # </powershell>
  # EOF
}
